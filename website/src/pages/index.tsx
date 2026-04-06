import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const quickLinks = [
  {
    title: 'Bootstrap The Repo',
    body: 'Init hooks, git helpers, shell aliases, and Unreal sync from one entry point.',
    to: '/docs/setup',
  },
  {
    title: 'Work Safely With UE Assets',
    body: 'Use the documented editor-only migration flow and guarded binary conflict helpers.',
    to: '/docs/workflow',
  },
  {
    title: 'Keep Docs In The Repo',
    body: 'ScareBandB is moving from Confluence to Docusaurus. Docs live in Docs/, not in a wiki.',
    to: '/docs/docs-site/setup',
  },
];

const highlights = [
  'Repo tooling is portable across UE 5.7 projects.',
  'Docs source lives in Docs/ and is rendered by website/.',
  'Script tests cover hooks, Unreal sync, aliases, and ArtSource helpers.',
];

export default function Home(): ReactNode {
  return (
    <Layout
      title="ScareBandB Docs"
      description="Repo tooling, Unreal workflow, and project documentation for ScareBandB.">
      <header className={styles.hero}>
        <div className={styles.heroBackdrop} />
        <div className={styles.heroBody}>
          <p className={styles.eyebrow}>UE 5.7 multiplayer haunting project</p>
          <Heading as="h1" className={styles.title}>
            ScareBandB
          </Heading>
          <p className={styles.subtitle}>
            Tooling, workflow, and project documentation for a co-op ghost game
            where players clear a rented house by frightening the guests out.
          </p>
          <div className={styles.actions}>
            <Link className="button button--primary button--lg" to="/docs/">
              Open Docs
            </Link>
            <Link className="button button--secondary button--lg" to="/docs/setup">
              Project Setup
            </Link>
          </div>
        </div>
      </header>
      <main>
        <section className={styles.section}>
          <div className={styles.sectionHeader}>
            <Heading as="h2">Start Here</Heading>
            <p>
              The repo already carries its own workflow. Use the docs and the
              scripts together, not as separate systems.
            </p>
          </div>
          <div className={styles.grid}>
            {quickLinks.map((item) => (
              <Link key={item.title} className={styles.card} to={item.to}>
                <Heading as="h3">{item.title}</Heading>
                <p>{item.body}</p>
              </Link>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.panel}>
            <Heading as="h2">Current Direction</Heading>
            <ul className={styles.panelList}>
              {highlights.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
        </section>
      </main>
    </Layout>
  );
}
