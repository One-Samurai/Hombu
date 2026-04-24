import "./globals.css";
import { Providers } from "./providers";
import { Toaster } from "sonner";

export const metadata = { title: "HONBU", description: "Fighter Hub" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-neutral-50 text-neutral-900">
        <Providers>{children}</Providers>
        <Toaster position="top-right" richColors />
      </body>
    </html>
  );
}
