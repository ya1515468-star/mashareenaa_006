-- Runtime repair: RLS policies and storage policies in production call these
-- private helper functions directly. They intentionally remain in the private
-- schema and are not exposed as public RPCs, but authenticated requests need
-- EXECUTE so PostgreSQL can evaluate those policies without 42501 failures.
GRANT EXECUTE ON FUNCTION private.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_room_permission(uuid, uuid, text) TO authenticated;
