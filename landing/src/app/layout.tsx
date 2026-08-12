import type { Metadata, Viewport } from "next"
import "./globals.css"

const TITLE = "DeskArt — Arrange your Mac Desktop icons into shapes"
const DESC =
  "A free macOS menu bar app that arranges your Desktop icons into text, hearts, spirals and twelve more shapes. Preview before applying, undo anything."

export const metadata: Metadata = {
  metadataBase: new URL("https://deskart.vercel.app"),
  title: TITLE,
  description: DESC,
  applicationName: "DeskArt",
  authors: [{ name: "Firas Latrach", url: "https://github.com/FirasLatrech" }],
  keywords: [
    "macOS", "Desktop icons", "menu bar app", "icon arrangement",
    "Finder", "open source", "Swift",
  ],
  openGraph: {
    title: TITLE,
    description: DESC,
    type: "website",
    siteName: "DeskArt",
    images: [{ url: "/og.png", width: 1024, height: 1024, alt: "DeskArt" }],
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: DESC,
    images: ["/og.png"],
  },
  icons: {
    icon: "/icon.png",
    apple: "/apple-touch-icon.png",
  },
}

export const viewport: Viewport = {
  themeColor: "#0c0c0c",
  colorScheme: "dark",
}

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  )
}
