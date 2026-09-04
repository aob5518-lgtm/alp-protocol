import type { Metadata } from "next";
import { cookies } from "next/headers";
import "./globals.css";
import "./locale.css";
import "./product.css";
import "./polish.css";
import Providers from "./providers";

export const metadata: Metadata = {
  title: "ALP — Asset Launch Protocol",
  description: "The infrastructure for launching global assets onchain.",
};

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const locale = (await cookies()).get("alp.locale")?.value === "zh-CN" ? "zh-CN" : "en-US";
  return (
    <html lang={locale}>
      <body><Providers initialLocale={locale}>{children}</Providers></body>
    </html>
  );
}
