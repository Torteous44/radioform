import type { Metadata } from "next";
import { Geist, Geist_Mono, Special_Elite, IBM_Plex_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const specialElite = Special_Elite({
  variable: "--font-special-elite",
  weight: "400",
  subsets: ["latin"],
});

const ibmPlexMono = IBM_Plex_Mono({
  variable: "--font-ibm-plex-mono",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Radioform: A macOS EQ App",
  description: "Radioform is an open source macOS EQ app that lives in your menubar.",
  icons: {
    icon: "/favicon.png",
  },
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
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${specialElite.variable} ${ibmPlexMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
