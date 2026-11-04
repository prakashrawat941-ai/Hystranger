-- Prevent users from self-assigning trust / verification attributes.
revoke update on public.profiles from authenticated;
grant update(full_name,avatar_url,date_of_birth,gender,city,bio,interests) on public.profiles to authenticated;
-- Explicit least-privilege grants for client workflows.
grant select on public.profiles,public.trips,public.join_requests,public.trip_members,public.messages to authenticated;
grant insert on public.trips,public.messages,public.reports,public.blocks to authenticated;
grant delete on public.trips,public.blocks to authenticated;
-- Membership and request state changes are RPC-only; clients cannot forge approvals.
revoke insert,update,delete on public.join_requests from authenticated;
revoke insert,update,delete on public.trip_members from authenticated;
revoke update,delete on public.messages from authenticated;
revoke update,delete on public.reports from authenticated;
-- No client may modify trip ownership or lifecycle through unrestricted table writes.
revoke update on public.trips from authenticated;
grant update(destination,region,start_date,end_date,departure_city,budget_amount,trip_type,gender_preference,min_age,max_age,max_group_size,cover_image_url,description,itinerary,join_policy) on public.trips to authenticated;
