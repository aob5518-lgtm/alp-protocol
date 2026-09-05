import type { Metadata } from "next";
import { cookies } from "next/headers";
import "./globals.css";
import "./locale.css";
import "./product.css";
import "./polish.css";
import Providers from "./providers";
import en from "../messages/en-US.json";
import zh from "../messages/zh-CN.json";
import "./content.css";

export async function generateMetadata():Promise<Metadata>{
  const messages=(await cookies()).get("alp.locale")?.value==="zh-CN"?zh:en;
  return {title:messages.common.metadataTitle,description:messages.common.metadataDescription};
}

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const locale = (await cookies()).get("alp.locale")?.value === "zh-CN" ? "zh-CN" : "en-US";
  return (
    <html lang={locale}>
      <body><Providers initialLocale={locale}>{children}</Providers></body>
    </html>
  );
}
