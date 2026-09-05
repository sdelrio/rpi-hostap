import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

const SITE_URL = 'https://sdelrio.github.io';
const BASE_PATH = '/rpi-hostap';

export default defineConfig({
  site: SITE_URL,
  base: BASE_PATH,
  integrations: [
    starlight({
      title: 'rpi-hostap',
      description: 'Lightweight Docker container that turns a Raspberry Pi into a wireless Access Point with DHCP server.',
      editLink: {
        baseUrl: 'https://github.com/sdelrio/rpi-hostap/edit/master/',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/sdelrio/rpi-hostap' },
      ],
      customCss: [
        './src/styles/custom.css',
      ],
      components: {
        ThemeProvider: './src/components/ThemeProvider.astro',
      },
      head: [
        {
          tag: 'link',
          attrs: { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        },
        {
          tag: 'link',
          attrs: { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: true },
        },
        {
          tag: 'link',
          attrs: {
            rel: 'stylesheet',
            href: 'https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap',
          },
        },
      ],
      plugins: [
        starlightLinksValidator(),
      ],
      sidebar: [
        { label: 'Home', link: '/readme' },
        {
          label: 'Configuration',
          items: [
            { label: 'Overview', link: '/configuration' },
            { label: 'HT/VHT Tuning', link: '/configuration#htvht-80211nac-tuning' },
            { label: 'MAC Filtering', link: '/configuration#mac-address-filtering-optional' },
            { label: 'WPA3 / SAE', link: '/configuration#wpa3-sae' },
            { label: 'Regional Channels', link: '/configuration#regional-channel-validation' },
          ],
        },
        {
          label: 'Networking',
          items: [
            { label: 'NAT / IP Forwarding', link: '/networking#nat--ip-forwarding' },
            { label: 'IPv6 Support', link: '/networking#ipv6-support-optional' },
            { label: 'Outgoing Interfaces', link: '/networking#outgoing-interfaces' },
          ],
        },
        { label: 'Validation', link: '/validation' },
        { label: 'Operations', link: '/operations' },
        { label: 'Health Check', link: '/healthcheck' },
        { label: 'Troubleshooting', link: '/troubleshooting' },
        { label: 'CI / E2E Tests', link: '/ci' },
        {
          label: 'Reference',
          items: [
            { label: 'Specification', link: '/spec' },
            { label: 'Changelog', link: '/changelog' },
          ],
        },
      ],
    }),
  ],
});
