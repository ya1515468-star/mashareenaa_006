-- Restore the authenticated execution contract for the client-side
-- self-destruct cleanup RPC. The function itself remains SECURITY DEFINER
-- and only deletes expired self-destruct messages from threads containing
-- auth.uid(), so this grant does not create cross-user deletion access.
grant execute on function public.cleanup_expired_self_destruct_messages() to authenticated;
