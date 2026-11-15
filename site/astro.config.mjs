import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';

// Pages come from ../docs via sync-docs.mjs (npm run sync). Edit the markdown there, not in src/.
export default defineConfig({
  site: 'https://homeloft.dev',
  integrations: [
    starlight({
      title: 'Homeloft',
      description: 'Home Assistant on your Synology, with your own cloud dashboard and API on AWS.',
      logo: { src: '../web/public/favicon.svg' },
      favicon: '/favicon.svg',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/EchoNin9/homeloft' }],
      sidebar: [
        { label: 'Get started', items: ['quickstart', 'synology', 'upgrading', 'troubleshooting'] },
        { label: 'Reference', items: ['architecture', 'configuration', 'contract', 'integrate', 'security', 'mobile'] },
        { label: 'Project', items: ['contributing', 'releasing', 'changelog', 'code-of-conduct'] },
        { label: 'Live demo', link: '/demo/', attrs: { target: '_blank' } },
      ],
      customCss: ['./theme.css'],
    }),
  ],
});
