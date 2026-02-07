import type { Metadata } from "next";
import { Instrument_Serif } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

const instrumentSerif = Instrument_Serif({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-serif",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://radioform.app"),
  title: "Radioform: A macOS EQ App",
  description:
    "Radioform is an open source macOS EQ app that lives in your menubar.",
  applicationName: "Radioform",
  keywords: [
    "macOS equalizer",
    "mac EQ app",
    "system-wide equalizer",
    "macOS audio equalizer",
    "free equalizer mac",
    "open source equalizer",
    "menu bar EQ",
    "macOS sound equalizer",
    "parametric equalizer mac",
    "audio EQ macOS",
    "mac sound enhancer",
    "system audio equalizer",
  ],
  authors: [{ name: "Pavlos RSA" }],
  creator: "Pavlos RSA",
  publisher: "Pavlos RSA",
  category: "Software",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/favicon.ico",
  },
  openGraph: {
    title: "Radioform: A macOS EQ App",
    description:
      "Radioform is an open source macOS EQ app that lives in your menubar.",
    url: "https://radioform.app",
    siteName: "Radioform",
    type: "website",
    locale: "en_US",
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
    description:
      "Radioform is an open source macOS EQ app that lives in your menubar.",
    images: ["/socialpreview.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${instrumentSerif.variable} antialiased`}>
        {children}
        <Analytics />
      </body>
    </html>
  );
}
