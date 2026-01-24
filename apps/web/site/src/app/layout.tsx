import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Radioform: A macOS EQ App",
  description: "Radioform is an open source macOS EQ app that lives in your menubar.",
  openGraph: {
    title: "Radioform: A macOS EQ App",
    description: "Radioform is an open source macOS EQ app that lives in your menubar.",
    images: [
      {
        url: "/socialpreview.png",
        width: 1200,
        height: 630,
        alt: "Radioform: A macOS EQ App",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Radioform: A macOS EQ App",
    description: "Radioform is an open source macOS EQ app that lives in your menubar.",
    images: ["/socialpreview.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
