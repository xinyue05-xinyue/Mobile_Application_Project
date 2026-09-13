import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@7";

Deno.serve(async (request) => {
  const cronSecret = Deno.env.get("REMINDER_CRON_SECRET");
  if (!cronSecret || request.headers.get("x-reminder-secret") !== cronSecret) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const gmailUser = Deno.env.get("GMAIL_USER")?.trim();
  const gmailPassword = Deno.env.get("GMAIL_APP_PASSWORD")?.replace(/\s/g, "");
  if (!gmailUser || !gmailPassword) return new Response("Gmail sender not configured", { status: 503 });
  const sender = `MyDarah <${gmailUser}>`;
  const mailer = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: gmailUser, pass: gmailPassword },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
  });
  let input: { action?: string };
  try {
    input = await request.json();
  } catch {
    return new Response("JSON body required", { status: 400 });
  }
  if (input?.action && input.action !== "check") {
    return new Response("Unsupported action", { status: 400 });
  }
  if (input?.action === "check") {
    try {
      await mailer.verify();
      return Response.json({ gmailConnection: "verified", emailSent: false });
    } catch {
      return Response.json({ error: "Gmail connection failed. Check the sender, App Password and account security settings." }, { status: 502 });
    } finally {
      mailer.close();
    }
  }
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: jobs, error } = await db.rpc("claim_event_email_reminders", { p_sender: sender });
  if (error) return new Response("Unable to claim reminders", { status: 500 });
  let sent = 0;
  for (const job of jobs ?? []) {
    try {
      const { data: current, error: readError } = await db.from("event_email_reminders")
        .select("status").eq("id", job.id).maybeSingle();
      if (readError) throw new Error("Reminder lookup failed");
      if (current?.status !== "sending") continue;
      const result = await mailer.sendMail({
        from: sender,
        to: job.email_payload.to,
        subject: job.email_payload.subject,
        text: job.email_payload.text,
        messageId: `<event-reminder-${job.id}@mydarah.invalid>`,
      });
      if (!result.accepted?.length) throw new Error("Email not accepted");
      const { error: updateError } = await db.from("event_email_reminders")
        .update({ status: "sent", sent_at: new Date().toISOString(), last_error: null })
        .eq("id", job.id).eq("status", "sending");
      if (updateError) throw new Error("Delivery recorded by provider; database update failed");
      sent++;
    } catch (error) {
      const { error: recordError } = await db.from("event_email_reminders")
        .update({ last_error: "Gmail delivery or acknowledgement failed; retry pending. Check sender settings and delivery before manually retrying." })
        .eq("id", job.id).eq("status", "sending");
      if (recordError) console.error("Unable to record reminder failure");
    }
  }
  mailer.close();
  return Response.json({ processed: jobs?.length ?? 0, acceptedByEmailProvider: sent });
});
