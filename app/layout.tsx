import type { Metadata, Viewport } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Hystranger — Find your next adventure partner', description: 'Meet travel buddies, discover trips and explore together.', applicationName: 'Hystranger', manifest: '/manifest.webmanifest', appleWebApp: { capable: true, statusBarStyle: 'black-translucent', title: 'Hystranger' }, icons: { icon: '/icon.svg', apple: '/icon.svg' } };
export const viewport: Viewport = { themeColor: '#0b1220', width: 'device-width', initialScale: 1, viewportFit: 'cover' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}<script dangerouslySetInnerHTML={{__html:"if ('serviceWorker' in navigator) addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));"}} /></body></html>; }
