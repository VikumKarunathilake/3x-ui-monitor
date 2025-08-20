import type React from "react"
import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "CeylonCloud Usage Monitor",
  description: "Monitor your VPN usage statistics",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-background font-sans antialiased">
        {children}
        <footer className="fixed bottom-0 right-0 p-2 text-xs text-muted-foreground opacity-70 hover:opacity-100 transition-opacity">
          <div className="text-right">
            <div>
              Created with ❤️ by{" "}
              <a 
                href="https://vikum.vercel.app" 
                target="_blank" 
                rel="noopener noreferrer" 
                className="underline hover:text-foreground transition-colors"
              >
                <strong>Vikum_K</strong>
              </a>{" "}
              /{" "}
              <a 
                href="https://ceyloncloud.site/" 
                target="_blank" 
                rel="noopener noreferrer" 
                className="underline hover:text-foreground transition-colors"
              >
                <strong>CeylonCloud</strong>
              </a>
            </div>
            <div>
              Licensed under{" "}
              <a
                href="https://creativecommons.org/licenses/by-nd/4.0/"
                target="_blank"
                rel="noopener noreferrer"
                className="underline hover:text-foreground transition-colors"
              >
                Creative Commons Attribution-NoDerivs (CC-BY-ND)
              </a>
            </div>
            <div>You may redistribute but cannot modify without permission</div>
          </div>
        </footer>
      </body>
    </html>
  )
}