import { redirect } from "next/navigation";

export default function Home() {
  // The dashboard layout handles auth-gating; unauthenticated users are bounced
  // to /login from there.
  redirect("/dashboard");
}
