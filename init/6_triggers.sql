CREATE OR REPLACE FUNCTION audit.log_user_login()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO audit.login_log (username, client_ip)
    VALUES (session_user, inet_client_addr());
END;
$$;

CREATE EVENT TRIGGER log_login_trigger ON login
EXECUTE FUNCTION audit.log_user_login();
