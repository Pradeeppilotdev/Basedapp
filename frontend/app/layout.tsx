import type { Metadata } from 'next';
import dynamic from 'next/dynamic';
import './globals.css';

const ClientProviders = dynamic(
  () => import('../lib/providers').then((module) => module.Providers),
  { ssr: false }
);

export const metadata: Metadata = {
  title: 'Base Daily Lottery - Win ETH Every Day!',
  description: 'Daily lottery on Base. Buy tickets, win prizes. Powered by blockchain.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="app-font">
        <ClientProviders>{children}</ClientProviders>
      </body>
    </html>
  );
}
