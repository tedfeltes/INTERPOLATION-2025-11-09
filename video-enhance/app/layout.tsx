import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Video Enhance — Local",
  description:
    "Enhance and clean up your own video, entirely on your machine. No uploads to any cloud.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
