import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "CyclopsVision - AI-Guided AR Training",
  description: "Create AR training lessons from demo videos with AI-powered step extraction",
  keywords: ["AR", "training", "AI", "lesson builder", "augmented reality"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} antialiased`}>
        {/* Background gradient effect */}
        <div className="fixed inset-0 pointer-events-none">
          <div
            className="absolute top-0 left-1/4 w-96 h-96 rounded-full opacity-20"
            style={{ background: "radial-gradient(circle, rgba(99, 102, 241, 0.3) 0%, transparent 70%)" }}
          />
          <div
            className="absolute bottom-1/4 right-1/4 w-96 h-96 rounded-full opacity-20"
            style={{ background: "radial-gradient(circle, rgba(139, 92, 246, 0.3) 0%, transparent 70%)" }}
          />
        </div>

        <div className="relative z-10">
          {children}
        </div>
      </body>
    </html>
  );
}
