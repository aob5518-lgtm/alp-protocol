import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ALP — Asset Launch Protocol",
  description: "The infrastructure for launching global assets onchain.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
