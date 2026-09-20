import type { ReactNode } from "react";

export const metadata = {
  title: "CardPulse Category API",
  description: "Transaction category inference for the CardPulse iOS app.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
