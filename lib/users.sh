#!/bin/bash

# =============================================================================
# Users Library for pgctl
# =============================================================================
# Functions for user management: create, delete, list, change password
# =============================================================================

# Prevent multiple sourcing
[[ -n "${PGCTL_USERS_LOADED:-}" ]] && return
PGCTL_USERS_LOADED=1

# Source dependencies
_USERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_USERS_DIR}/common.sh"
source "${_USERS_DIR}/permissions.sh"

# =============================================================================
# User Creation Wizard
# =============================================================================

# Interactive user creation wizard
create_user_wizard() {
    log_header "User Creation Wizard"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username
    local username
    username=$(prompt_input "Username")
    
    if [[ -z "$username" ]]; then
        log_error "Username cannot be empty"
        return 1
    fi
    
    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi
    
    # Check if user already exists
    if user_exists "$username"; then
        log_error "User '$username' already exists"
        return 1
    fi
    
    # Select role type
    local role_types=("readonly_user" "app_user" "fullaccess_user" "migration_user" "owner" "custom")
    local role_type
    role_type=$(prompt_select "Select role type:" "${role_types[@]}")
    
    if [[ -z "$role_type" ]]; then
        log_error "No role type selected"
        return 1
    fi
    
    # Handle custom permissions
    local custom_table_perms=""
    local custom_seq_perms=""
    local custom_func_perms=""
    
    if [[ "$role_type" == "custom" ]]; then
        echo ""
        log_info "Select custom permissions:"
        
        local table_options=("SELECT" "INSERT" "UPDATE" "DELETE" "ALL")
        custom_table_perms=$(prompt_select_multiple "Table permissions:" "${table_options[@]}")
        custom_table_perms=$(echo "$custom_table_perms" | tr '\n' ', ' | sed 's/,$//')
        
        local seq_options=("USAGE" "SELECT" "ALL")
        custom_seq_perms=$(prompt_select_multiple "Sequence permissions:" "${seq_options[@]}")
        custom_seq_perms=$(echo "$custom_seq_perms" | tr '\n' ', ' | sed 's/,$//')
        
        custom_func_perms="EXECUTE"
    fi
    
    # Ask about future objects
    echo ""
    local apply_future=true
    if ! prompt_confirm "Apply permissions to future objects? (Recommended)"; then
        apply_future=false
    fi
    
    # Get target database(s)
    local databases
    databases=$(list_databases_query)
    
    if [[ -z "$databases" ]]; then
        log_error "No databases found"
        return 1
    fi
    
    echo ""
    local target_dbs
    target_dbs=$(prompt_select_multiple "Select target database(s):" $databases)
    
    if [[ -z "$target_dbs" ]]; then
        log_error "No databases selected"
        return 1
    fi
    
    # Get password
    echo ""
    local password
    password=$(prompt_password "Password for $username")
    
    if [[ -z "$password" ]]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Show summary
    echo ""
    local summary="User: $username
Role type: $role_type
Target database(s): $(echo "$target_dbs" | tr '\n' ', ' | sed 's/,$//')
Future objects: $(if $apply_future; then echo "Yes"; else echo "No"; fi)"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum style --border rounded --padding "1 2" --border-foreground 12 "Summary" "$summary"
    else
        echo ""
        echo "Summary:"
        echo "$summary"
        echo ""
    fi
    
    # Confirm
    if ! prompt_confirm "Create user with these settings?"; then
        log_info "User creation cancelled"
        return 0
    fi
    
    echo ""
    
    # Create user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Creating user $username..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"CREATE ROLE $username WITH LOGIN PASSWORD '$password';\" > /dev/null 2>&1"
    else
        echo -n "Creating user $username... "
        psql_admin_quiet "CREATE ROLE $username WITH LOGIN PASSWORD '$password';"
    fi
    log_success "User created"
    
    # Apply permissions to each database
    while IFS= read -r dbname; do
        [[ -z "$dbname" ]] && continue
        
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Granting permissions on $dbname..." -- \
                bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                         if [[ '$role_type' == 'custom' ]]; then
                             psql_admin_quiet \"GRANT USAGE ON SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_table_perms ON ALL TABLES IN SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_seq_perms ON ALL SEQUENCES IN SCHEMA public TO $username;\" '$dbname'
                             psql_admin_quiet \"GRANT $custom_func_perms ON ALL FUNCTIONS IN SCHEMA public TO $username;\" '$dbname'
                         else
                             grant_all_permissions '$dbname' '$username' '$role_type' 'public'
                         fi"
        else
            echo -n "Granting permissions on $dbname... "
            if [[ "$role_type" == "custom" ]]; then
                psql_admin_quiet "GRANT USAGE ON SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_table_perms ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_seq_perms ON ALL SEQUENCES IN SCHEMA public TO $username;" "$dbname"
                psql_admin_quiet "GRANT $custom_func_perms ON ALL FUNCTIONS IN SCHEMA public TO $username;" "$dbname"
            else
                grant_all_permissions "$dbname" "$username" "$role_type" "public"
            fi
        fi
        log_success "Permissions granted on $dbname"
        
        # Set default privileges for future objects
        if $apply_future; then
            if [[ "$GUM_AVAILABLE" == "true" ]]; then
                gum spin --spinner dot --title "Setting default privileges on $dbname..." -- \
                    bash -c "source '${PGCTL_LIB_DIR}/permissions.sh'
                             # Set default privileges for objects created by the db owner
                             local db_owner=\"${dbname}_owner\"
                             if user_exists \"\$db_owner\"; then
                                 set_default_privileges '$dbname' \"\$db_owner\" '$username' '$role_type' 'public'
                             fi"
            else
                echo -n "Setting default privileges on $dbname... "
                local db_owner="${dbname}_owner"
                if user_exists "$db_owner"; then
                    set_default_privileges "$dbname" "$db_owner" "$username" "$role_type" "public"
                fi
            fi
            log_success "Default privileges set on $dbname"
        fi
    done <<< "$target_dbs"
    
    echo ""
    log_success "User $username created successfully"
}

# =============================================================================
# View/Manage User Permissions
# =============================================================================

# View and manage user permissions interactively
view_user_permissions() {
    local username="${1:-}"
    local dbname="${2:-}"
    
    log_header "User Permission Management"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_users_query)
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        username=$(prompt_select "Select user:" $users)
        
        if [[ -z "$username" ]]; then
            log_error "No user selected"
            return 1
        fi
    fi
    
    # Get database if not provided
    if [[ -z "$dbname" ]]; then
        local databases
        databases=$(list_databases_query)
        
        if [[ -z "$databases" ]]; then
            log_error "No databases found"
            return 1
        fi
        
        dbname=$(prompt_select "Select database:" $databases)
        
        if [[ -z "$dbname" ]]; then
            log_error "No database selected"
            return 1
        fi
    fi
    
    while true; do
        echo ""
        log_info "User: $username | Database: $dbname"
        echo ""
        
        # Show schema permissions
        echo "Schema Permissions:"
        get_user_schema_permissions "$dbname" "$username"
        
        echo ""
        
        # Show table permissions summary
        echo "Table Permissions:"
        local table_perms
        table_perms=$(psql_admin "SELECT privilege_type, COUNT(*) as count 
                                   FROM information_schema.role_table_grants 
                                   WHERE grantee = '$username' AND table_schema = 'public'
                                   GROUP BY privilege_type
                                   ORDER BY privilege_type;" "$dbname" 2>/dev/null)
        echo "$table_perms"
        
        echo ""
        
        # Menu options
        local options=("Extend Permissions" "Revoke Permissions" "View Object Details" "Back to Main Menu")
        local action
        action=$(prompt_select "Select action:" "${options[@]}")
        
        case "$action" in
            "Extend Permissions")
                extend_user_permissions "$dbname" "$username"
                ;;
            "Revoke Permissions")
                revoke_user_permissions "$dbname" "$username"
                ;;
            "View Object Details")
                view_object_details "$dbname" "$username"
                ;;
            "Back to Main Menu"|"")
                return 0
                ;;
        esac
    done
}

# Extend user permissions
extend_user_permissions() {
    local dbname="$1"
    local username="$2"
    
    log_info "Extend Permissions for $username"
    echo ""
    
    local perm_options=("SELECT on all tables" "INSERT on all tables" "UPDATE on all tables" "DELETE on all tables" "USAGE on all sequences" "EXECUTE on all functions" "CREATE on schema")
    
    local selected
    selected=$(prompt_select_multiple "Select permissions to add:" "${perm_options[@]}")
    
    if [[ -z "$selected" ]]; then
        log_info "No permissions selected"
        return 0
    fi
    
    if ! prompt_confirm "Apply these permissions?"; then
        return 0
    fi
    
    echo ""
    
    while IFS= read -r perm; do
        [[ -z "$perm" ]] && continue
        
        case "$perm" in
            "SELECT on all tables")
                psql_admin_quiet "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "INSERT on all tables")
                psql_admin_quiet "GRANT INSERT ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "UPDATE on all tables")
                psql_admin_quiet "GRANT UPDATE ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "DELETE on all tables")
                psql_admin_quiet "GRANT DELETE ON ALL TABLES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "USAGE on all sequences")
                psql_admin_quiet "GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO $username;" "$dbname"
                ;;
            "EXECUTE on all functions")
                psql_admin_quiet "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO $username;" "$dbname"
                ;;
            "CREATE on schema")
                psql_admin_quiet "GRANT CREATE ON SCHEMA public TO $username;" "$dbname"
                ;;
        esac
        log_success "Granted: $perm"
    done <<< "$selected"
    
    echo ""
    log_success "Permissions extended successfully"
}

# Revoke user permissions
revoke_user_permissions() {
    local dbname="$1"
    local username="$2"
    
    log_info "Revoke Permissions from $username"
    log_warning "Revoking permissions may break application functionality"
    echo ""
    
    local perm_options=("SELECT on all tables" "INSERT on all tables" "UPDATE on all tables" "DELETE on all tables" "USAGE on all sequences" "EXECUTE on all functions" "CREATE on schema" "ALL on all tables")
    
    local selected
    selected=$(prompt_select_multiple "Select permissions to revoke:" "${perm_options[@]}")
    
    if [[ -z "$selected" ]]; then
        log_info "No permissions selected"
        return 0
    fi
    
    if ! prompt_confirm "Are you sure you want to revoke these permissions?"; then
        return 0
    fi
    
    echo ""
    
    while IFS= read -r perm; do
        [[ -z "$perm" ]] && continue
        
        case "$perm" in
            "SELECT on all tables")
                psql_admin_quiet "REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "INSERT on all tables")
                psql_admin_quiet "REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "UPDATE on all tables")
                psql_admin_quiet "REVOKE UPDATE ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "DELETE on all tables")
                psql_admin_quiet "REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "USAGE on all sequences")
                psql_admin_quiet "REVOKE USAGE ON ALL SEQUENCES IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "EXECUTE on all functions")
                psql_admin_quiet "REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM $username;" "$dbname"
                ;;
            "CREATE on schema")
                psql_admin_quiet "REVOKE CREATE ON SCHEMA public FROM $username;" "$dbname"
                ;;
            "ALL on all tables")
                psql_admin_quiet "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM $username;" "$dbname"
                ;;
        esac
        log_success "Revoked: $perm"
    done <<< "$selected"
    
    echo ""
    log_success "Permissions revoked successfully"
}

# View object details
view_object_details() {
    local dbname="$1"
    local username="$2"
    
    log_info "Object Details for $username in $dbname"
    echo ""
    
    local sql="SELECT table_name, STRING_AGG(privilege_type, ', ' ORDER BY privilege_type) as privileges
               FROM information_schema.role_table_grants
               WHERE grantee = '$username' AND table_schema = 'public'
               GROUP BY table_name
               ORDER BY table_name;"
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" "$dbname" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql" "$dbname"
    fi
}

# =============================================================================
# User Management Functions
# =============================================================================

# Change user password
change_user_password() {
    local username="${1:-}"
    
    log_header "Change User Password"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_users_query)
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        username=$(prompt_select "Select user:" $users)
        
        if [[ -z "$username" ]]; then
            log_error "No user selected"
            return 1
        fi
    fi
    
    # Verify user exists
    if ! user_exists "$username"; then
        log_error "User '$username' does not exist"
        return 1
    fi
    
    # Get new password
    echo ""
    local password
    password=$(prompt_password "New password for $username")
    
    if [[ -z "$password" ]]; then
        log_error "Password cannot be empty"
        return 1
    fi
    
    # Confirm password
    local password_confirm
    password_confirm=$(prompt_password "Confirm password")
    
    if [[ "$password" != "$password_confirm" ]]; then
        log_error "Passwords do not match"
        return 1
    fi
    
    # Change password
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Changing password..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c \"ALTER ROLE $username WITH PASSWORD '$password';\" > /dev/null 2>&1"
    else
        echo -n "Changing password... "
        psql_admin_quiet "ALTER ROLE $username WITH PASSWORD '$password';"
    fi
    
    echo ""
    log_success "Password changed successfully for $username"
}

# Delete user
delete_user() {
    local username="${1:-}"
    
    log_header "Delete User"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    # Get username if not provided
    if [[ -z "$username" ]]; then
        local users
        users=$(list_users_query)
        
        if [[ -z "$users" ]]; then
            log_error "No users found"
            return 1
        fi
        
        username=$(prompt_select "Select user to delete:" $users)
        
        if [[ -z "$username" ]]; then
            log_error "No user selected"
            return 1
        fi
    fi
    
    # Verify user exists
    if ! user_exists "$username"; then
        log_error "User '$username' does not exist"
        return 1
    fi
    
    # Check for owned objects
    local owned_objects
    owned_objects=$(psql_admin "SELECT COUNT(*) FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = '$username');" 2>/dev/null | tail -n +3 | head -n 1 | tr -d ' ')
    
    if [[ "${owned_objects:-0}" -gt 0 ]]; then
        log_warning "User '$username' owns $owned_objects objects"
        log_warning "These objects must be reassigned or dropped before the user can be deleted"
        
        if ! prompt_confirm "Do you want to reassign objects to postgres and then delete?"; then
            log_info "Deletion cancelled"
            return 0
        fi
        
        # Reassign owned objects
        if [[ "$GUM_AVAILABLE" == "true" ]]; then
            gum spin --spinner dot --title "Reassigning owned objects..." -- \
                bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c 'REASSIGN OWNED BY $username TO $PGADMIN;' > /dev/null 2>&1"
        else
            echo -n "Reassigning owned objects... "
            psql_admin_quiet "REASSIGN OWNED BY $username TO $PGADMIN;"
        fi
        log_success "Objects reassigned"
    fi
    
    log_warning "This will permanently delete user '$username'"
    
    if ! prompt_confirm "Are you sure you want to delete this user?"; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    # Drop owned (privileges, etc.)
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Revoking privileges..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c 'DROP OWNED BY $username;' > /dev/null 2>&1"
    else
        echo -n "Revoking privileges... "
        psql_admin_quiet "DROP OWNED BY $username;"
    fi
    
    # Delete user
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        gum spin --spinner dot --title "Deleting user $username..." -- \
            bash -c "PGPASSWORD='$PGPASSWORD' psql -h '$PGHOST' -p '$PGPORT' -U '$PGADMIN' -c 'DROP ROLE $username;' > /dev/null 2>&1"
    else
        echo -n "Deleting user $username... "
        psql_admin_quiet "DROP ROLE $username;"
    fi
    
    echo ""
    log_success "User '$username' deleted successfully"
}

# List users
list_users() {
    local dbname="${1:-}"
    
    log_header "Database Users"
    
    # Check connection
    if ! check_connection; then
        return 1
    fi
    
    local sql
    
    if [[ -n "$dbname" ]]; then
        log_info "Database: $dbname"
        echo ""
        
        # List users with access to this database
        sql="SELECT r.rolname AS username,
             CASE 
                 WHEN r.rolname LIKE '%_owner' THEN 'owner'
                 WHEN r.rolname LIKE '%_migration_user' THEN 'migration'
                 WHEN r.rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                 WHEN r.rolname LIKE '%_app_user' THEN 'app'
                 WHEN r.rolname LIKE '%_readonly_user' THEN 'readonly'
                 ELSE 'custom'
             END AS role_type,
             CASE WHEN r.rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login,
             CASE WHEN r.rolcreatedb THEN 'Yes' ELSE 'No' END AS can_createdb,
             CASE WHEN r.rolcreaterole THEN 'Yes' ELSE 'No' END AS can_createrole
             FROM pg_roles r
             WHERE r.rolcanlogin = true
             AND (r.rolname LIKE '${dbname}_%' OR r.rolname = 'postgres')
             ORDER BY r.rolname;"
    else
        # List all users
        sql="SELECT r.rolname AS username,
             CASE 
                 WHEN r.rolname LIKE '%_owner' THEN 'owner'
                 WHEN r.rolname LIKE '%_migration_user' THEN 'migration'
                 WHEN r.rolname LIKE '%_fullaccess_user' THEN 'fullaccess'
                 WHEN r.rolname LIKE '%_app_user' THEN 'app'
                 WHEN r.rolname LIKE '%_readonly_user' THEN 'readonly'
                 ELSE 'custom'
             END AS role_type,
             CASE WHEN r.rolcanlogin THEN 'Yes' ELSE 'No' END AS can_login
             FROM pg_roles r
             WHERE r.rolcanlogin = true
             AND r.rolname NOT LIKE 'pg_%'
             ORDER BY r.rolname;"
    fi
    
    if [[ "$GUM_AVAILABLE" == "true" ]]; then
        local result
        result=$(psql_admin "$sql" 2>/dev/null)
        echo "$result" | gum table
    else
        psql_admin "$sql"
    fi
}

# =============================================================================
# Command Wrappers for CLI
# =============================================================================

cmd_create_user() {
    create_user_wizard "$@"
}

cmd_change_password() {
    change_user_password "$@"
}

cmd_delete_user() {
    delete_user "$@"
}

cmd_list_users() {
    list_users "$@"
}

cmd_view_user() {
    view_user_permissions "$@"
}

# =============================================================================
# Register Commands
# =============================================================================

register_command "Create User" "USER MANAGEMENT" "cmd_create_user" \
    "Interactive user creation wizard"

register_command "Change Password" "USER MANAGEMENT" "cmd_change_password" \
    "Change user password"

register_command "Delete User" "USER MANAGEMENT" "cmd_delete_user" \
    "Delete a user"

register_command "List Users" "USER MANAGEMENT" "cmd_list_users" \
    "List all database users"

register_command "View User Permissions" "USER MANAGEMENT" "cmd_view_user" \
    "View and manage user permissions"
