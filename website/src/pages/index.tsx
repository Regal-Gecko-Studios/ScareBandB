import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const primaryActions = [
  {
    title: 'Read The Design',
    body: 'Start with the ghost fantasy, the match structure, and the current gameplay loop before touching implementation.',
    to: '/docs/game-design/overview',
  },
  {
    title: 'Ship Safely',
    body: 'Use the repo workflow, guarded binary tooling, and testing notes without letting process take over the project.',
    to: '/docs/workflow',
  },
  {
    title: 'Get Running',
    body: 'Bootstrap the repo, sync the project, and get back into Unreal quickly.',
    to: '/docs/setup',
  },
];

const sectionCards = [
  {
    title: 'Game Design',
    body: 'Core loop, round structure, fear systems, and the current playable direction.',
    to: '/docs/game-design/overview',
    badge: 'Design',
  },
  {
    title: 'Project Structure',
    body: 'Canonical folder expectations, migration rules, and where assets and code belong.',
    to: '/docs/project-structure',
    badge: 'Structure',
  },
  {
    title: 'Workflow',
    body: 'Branch discipline, binary safety, repo hygiene, and daily development flow.',
    to: '/docs/workflow',
    badge: 'Process',
  },
  {
    title: 'Testing',
    body: 'What the automation covers, what must stay green, and how to validate safely.',
    to: '/docs/testing',
    badge: 'Validation',
  },
  {
    title: 'Coding Standards',
    body: 'The current Unreal C++ guidance and the local snapshot workflow that backs it.',
    to: '/docs/coding-standards',
    badge: 'Code',
  },
];

const readOrder = [
  {label: 'Setup', to: '/docs/setup'},
  {label: 'Game Design', to: '/docs/game-design/overview'},
  {label: 'Project Structure', to: '/docs/project-structure'},
  {label: 'Workflow', to: '/docs/workflow'},
  {label: 'Testing', to: '/docs/testing'},
];

const principles = [
  'Build gameplay first. Tooling exists to remove friction, not create it.',
  'Keep docs in the repo so design, workflow, and code stay in the same review loop.',
  'Use the documented Unreal-safe flows for assets, structure changes, and validation.',
];

const metrics = [
  {value: '4', label: 'Ghost players'},
  {value: '1', label: 'Haunted inn'},
  {value: 'UE 5.7', label: 'Engine target'},
];

export default function Home(): ReactNode {
  const logoSrc = useBaseUrl('/img/logo.svg');

  return (
    <Layout
      title="ScareBandB Docs"
      description="Repo tooling, Unreal workflow, and project documentation for ScareBandB.">
      <header className={styles.hero}>
        <div className={styles.heroBackdrop} />
        <div className={styles.heroGrid}>
          <div className={styles.heroCopy}>
            <div className={styles.brandLockup}>
              <img className={styles.brandMark} src={logoSrc} alt="ScareBandB ghost mark" />
              <p className={styles.eyebrow}>Co-op haunting project overview</p>
            </div>
            <Heading as="h1" className={styles.title}>
              ScareBandB
            </Heading>
            <p className={styles.subtitle}>
              A lean project overview for the ghost fantasy, gameplay loop,
              Unreal workflow, and the rules that actually matter during
              development.
            </p>
            <div className={styles.actions}>
              <Link className="button button--primary button--lg" to="/docs/">
                Open Overview
              </Link>
              <Link className={styles.ghostButton} to="/docs/game-design/overview">
                Read Game Design
              </Link>
            </div>
            <div className={styles.metrics}>
              {metrics.map((item) => (
                <div key={item.label} className={styles.metric}>
                  <strong>{item.value}</strong>
                  <span>{item.label}</span>
                </div>
              ))}
            </div>
          </div>
          <aside className={styles.heroPanel}>
            <p className={styles.panelEyebrow}>Recommended Read Order</p>
            <Heading as="h2">Start building the game, not wrestling the tooling.</Heading>
            <ol className={styles.readOrder}>
              {readOrder.map((item) => (
                <li key={item.label}>
                  <Link to={item.to}>{item.label}</Link>
                </li>
              ))}
            </ol>
          </aside>
        </div>
      </header>
      <main>
        <section className={styles.section}>
          <div className={styles.sectionHeader}>
            <p className={styles.sectionLabel}>Build Tonight</p>
            <Heading as="h2">Use the docs like a production handbook.</Heading>
            <p>
              The goal is not to document everything. The goal is to keep the
              next important decision obvious.
            </p>
          </div>
          <div className={styles.grid}>
            {primaryActions.map((item) => (
              <Link key={item.title} className={styles.primaryCard} to={item.to}>
                <Heading as="h3">{item.title}</Heading>
                <p>{item.body}</p>
                <span>Open</span>
              </Link>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.sectionHeader}>
            <p className={styles.sectionLabel}>Core Sections</p>
            <Heading as="h2">Keep the important pages close.</Heading>
          </div>
          <div className={styles.cardGrid}>
            {sectionCards.map((item) => (
              <Link key={item.title} className={styles.card} to={item.to}>
                <span className={styles.cardBadge}>{item.badge}</span>
                <Heading as="h3">{item.title}</Heading>
                <p>{item.body}</p>
                <span className={styles.cardLink}>Open section</span>
              </Link>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.principles}>
            <div className={styles.principlesCopy}>
              <p className={styles.sectionLabel}>Ground Rules</p>
              <Heading as="h2">Keep the docs sharp. Keep the process lean.</Heading>
            </div>
            <div className={styles.principlesList}>
              {principles.map((item) => (
                <div key={item} className={styles.principle}>
                  <span className={styles.principleMark} />
                  <p>{item}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.closingPanel}>
            <Heading as="h2">Docs belong next to the work.</Heading>
            <p>
              ScareBandB does not need a sprawling wiki. It needs a readable
              design reference, a trustworthy workflow, and enough structure
              to help the team ship.
            </p>
            <div className={styles.actions}>
              <Link className="button button--primary button--lg" to="/docs/workflow">
                Workflow
              </Link>
              <Link className={styles.ghostButton} to="/docs/testing">
                Validation
              </Link>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
