import type { Metadata } from "next";
import "./globals.css";
import Providers from "./providers";

export const metadata: Metadata = {
  title: "ALP — Asset Launch Protocol",
  description: "The infrastructure for launching global assets onchain.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-US">
      <body><Providers>{children}</Providers></body>
    </html>
  );
}
