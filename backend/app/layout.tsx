import type { ReactNode } from "react";

export const metadata = {
  title: "CardLah! Category API",
  description: "Transaction category inference for the CardLah! iOS app.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
