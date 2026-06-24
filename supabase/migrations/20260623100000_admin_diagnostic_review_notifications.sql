-- Allow the scheduled AI diagnostics reviewer to notify admin users in-app.
ALTER TYPE public.notification_type ADD VALUE IF NOT EXISTS 'admin_diagnostics_review';