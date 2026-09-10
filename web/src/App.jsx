import { useEffect, useState } from 'react';
import './App.css';
import { config, isPlaceholder } from './config';
import { Icon } from './Icon';

/* ------------------------------------------------------------------ data */

const ROLES = [
  {
    icon: 'package',
    title: 'Chargeur',
    text: "Publiez une demande de transport en quelques minutes, comparez les offres et suivez la marchandise jusqu'à la livraison.",
    points: [
      'Prix fixe ou appel d’offres',
      'Suivi du statut en temps réel',
      'Confirmation de réception et notation',
      'Factures et documents centralisés',
    ],
  },
  {
    icon: 'truck',
    title: 'Transporteur',
    text: 'Trouvez des chargements sur votre corridor, gérez votre flotte et vos chauffeurs, et limitez les retours à vide.',
    points: [
      'Bourse de chargements filtrée par wilaya',
      'Acceptation directe ou soumission d’offre',
      'Flotte et chauffeurs avec alertes de documents',
      'Suggestions de chargement retour',
    ],
  },
  {
    icon: 'wheel',
    title: 'Chauffeur',
    text: 'Un écran, une seule action à la fois. Conçu pour être utilisable d’une main, en cabine, avec un réseau instable.',
    points: [
      'Mission du jour en un coup d’œil',
      'Fonctionne hors ligne, synchronise au retour du réseau',
      'Photos de chargement obligatoires',
      'Preuve de livraison avec signature',
    ],
  },
  {
    icon: 'shield',
    title: 'Administration',
    text: 'Pilotage complet de la plateforme : attribution, facturation, litiges, et rapports de marge.',
    points: [
      'Attribution et réattribution des trajets',
      'Facturation, paiements et relances',
      'Résolution des litiges',
      'Rapports de marge et journal d’audit',
    ],
  },
];

const FEATURES = [
  {
    icon: 'route',
    title: 'Cycle de vie complet',
    text: 'Quatorze étapes, de la demande à la clôture, avec un historique horodaté de chaque changement de statut.',
  },
  {
    icon: 'pin',
    title: 'Suivi en direct',
    text: 'Position GPS du camion pendant le trajet, transmise en temps réel au chargeur et à l’administration.',
  },
  {
    icon: 'offline',
    title: 'Résistant au réseau',
    text: 'Le chauffeur continue de travailler sans connexion : les actions sont mises en file et envoyées automatiquement.',
  },
  {
    icon: 'doc',
    title: 'Documents générés',
    text: 'Bon de transport, bon de livraison, preuve de livraison signée et facture numérotée, produits par la plateforme.',
  },
  {
    icon: 'globe',
    title: 'Arabe, français, anglais',
    text: 'Interface complète dans les trois langues, avec mise en page RTL pour l’arabe et bascule instantanée.',
  },
  {
    icon: 'bell',
    title: 'Notifications',
    text: 'Nouvelle offre, trajet attribué, incident, facture due — poussées en direct vers les personnes concernées.',
  },
];

const LIFECYCLE = [
  'Publiée',
  'Offres reçues',
  'Attribuée',
  'Chauffeur assigné',
  'Vers chargement',
  'Chargé',
  'En route',
  'Livré',
  'Confirmé',
  'Facturée',
  'Payée',
];

const STATS = [
  { value: '4', label: 'rôles métier' },
  { value: '58', label: 'wilayas couvertes' },
  { value: '3', label: 'langues (AR/FR/EN)' },
];

/* ------------------------------------------------------------ components */

function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <header className={`nav ${scrolled ? 'nav--scrolled' : ''}`}>
      <div className="shell nav__inner">
        <a className="brand" href="#top" aria-label={`${config.appName} — accueil`}>
          <span className="brand__mark" aria-hidden="true">
            <Icon name="truck" size={19} />
          </span>
          {config.appName}
        </a>

        <nav className="nav__links" aria-label="Navigation principale">
          <a className="nav__link" href="#roles">Rôles</a>
          <a className="nav__link" href="#features">Fonctionnalités</a>
          <a className="nav__link" href="#lifecycle">Déroulé</a>
          <a className="nav__link" href="#download">Télécharger</a>
        </nav>

        <DownloadButton small />
      </div>
    </header>
  );
}

/** The primary call to action. While `apkUrl` is still a placeholder it renders
 *  as a clearly disabled control instead of a link that goes nowhere. */
function DownloadButton({ small = false, ghost = false }) {
  const pending = isPlaceholder(config.apkUrl);
  const cls = `btn ${small ? 'btn--sm' : ''} ${
    pending ? 'btn--disabled' : ghost ? 'btn--ghost' : 'btn--primary'
  }`;

  if (pending) {
    return (
      <span className={cls} role="button" aria-disabled="true" title="Lien de téléchargement à venir">
        <Icon name="download" size={17} />
        Bientôt disponible
      </span>
    );
  }

  return (
    <a className={cls} href={config.apkUrl} download>
      <Icon name="download" size={17} />
      {small ? 'Télécharger' : "Télécharger l'application"}
    </a>
  );
}

function Hero() {
  return (
    <section className="hero" id="top">
      <div className="shell hero__grid">
        <div>
          <span className="eyebrow">{config.tagline}</span>
          <h1 className="hero__title">
            Le transport de marchandises, <em>de bout en bout</em>.
          </h1>
          <p className="hero__sub">
            {config.appName} relie chargeurs, transporteurs et chauffeurs sur une seule
            plateforme : publication du besoin, mise en relation, suivi du camion,
            preuve de livraison et facturation.
          </p>

          <div className="hero__cta">
            <DownloadButton />
            <a className="btn btn--ghost" href="#roles">
              Découvrir les rôles
              <Icon name="arrow" size={16} />
            </a>
          </div>

          <p className="hero__note">Android · Gratuit · Arabe, français et anglais</p>

          <div className="hero__stats">
            {STATS.map((s) => (
              <div key={s.label}>
                <div className="stat__value">{s.value}</div>
                <div className="stat__label">{s.label}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="hero__visual">
          <PhoneMock />
        </div>
      </div>
    </section>
  );
}

/** A stylised rendering of the driver's mission screen — the app's most
 *  distinctive view (one route, one action). Decorative, so hidden from
 *  assistive tech. */
function PhoneMock() {
  return (
    <div className="phone" aria-hidden="true">
      <div className="phone__screen">
        <div className="phone__bar">
          <div className="phone__route">Alger → Oran</div>
          <div className="phone__ref">Mission PP-2026-000042</div>
        </div>

        <div className="phone__body">
          <div className="mock-card">
            <div className="mock-card__label">Chargeur</div>
            <div className="mock-card__value">SARL Karim Matériaux</div>
          </div>

          <div className="mock-card">
            <div className="mock-card__label">Marchandise</div>
            <div className="mock-card__value">Ciment · 24 000 kg</div>
          </div>

          <div className="mock-card mock-steps">
            <div className="mock-step mock-step--done">
              <span className="mock-step__dot" />
              Départ vers chargement
            </div>
            <div className="mock-step mock-step--done">
              <span className="mock-step__dot" />
              Chargement terminé
            </div>
            <div className="mock-step mock-step--now">
              <span className="mock-step__dot" />
              En route vers livraison
            </div>
            <div className="mock-step">
              <span className="mock-step__dot" />
              Arrivé à destination
            </div>
          </div>

          <div className="mock-action">Je suis arrivé</div>
        </div>
      </div>
    </div>
  );
}

function Roles() {
  return (
    <section className="section roles" id="roles">
      <div className="shell">
        <div className="section__head">
          <span className="eyebrow">Quatre rôles</span>
          <h2 className="section__title">Une application, quatre métiers</h2>
          <p className="section__sub">
            Chaque rôle voit uniquement ce qui le concerne, avec une interface pensée
            pour sa réalité de terrain.
          </p>
        </div>

        <div className="grid grid--4">
          {ROLES.map((role) => (
            <article className="card" key={role.title}>
              <div className="card__icon">
                <Icon name={role.icon} size={21} />
              </div>
              <h3 className="card__title">{role.title}</h3>
              <p className="card__text">{role.text}</p>
              <ul className="card__list">
                {role.points.map((p) => (
                  <li key={p}>{p}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section className="section" id="features">
      <div className="shell">
        <div className="section__head">
          <span className="eyebrow">Fonctionnalités</span>
          <h2 className="section__title">Ce que la plateforme prend en charge</h2>
        </div>

        <div className="grid grid--3">
          {FEATURES.map((f) => (
            <article className="card" key={f.title}>
              <div className="card__icon">
                <Icon name={f.icon} size={21} />
              </div>
              <h3 className="card__title">{f.title}</h3>
              <p className="card__text">{f.text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function Lifecycle() {
  return (
    <section className="section section--tight" id="lifecycle">
      <div className="shell">
        <div className="section__head">
          <span className="eyebrow">Déroulé d’un trajet</span>
          <h2 className="section__title">De la demande au paiement</h2>
          <p className="section__sub">
            Chaque étape est horodatée et attribuée à son auteur, ce qui laisse une piste
            d’audit complète sur toute la durée du trajet.
          </p>
        </div>

        <ol className="flow" aria-label="Étapes du cycle de vie d’un trajet">
          {LIFECYCLE.map((step, i) => (
            <li className="flow__step" key={step}>
              <span className="flow__num">{i + 1}</span>
              {step}
            </li>
          ))}
        </ol>

        <div className="badge-row">
          <span className="badge badge--accent">Prix fixe ou appel d’offres</span>
          <span className="badge badge--ok">Preuve de livraison signée</span>
          <span className="badge">Litiges et incidents</span>
          <span className="badge">Journal d’audit</span>
        </div>
      </div>
    </section>
  );
}

function Download() {
  const pending = isPlaceholder(config.apkUrl);

  return (
    <section className="section" id="download">
      <div className="shell">
        <div className="download">
          <h2 className="download__title">Essayez {config.appName}</h2>
          <p className="download__sub">
            {pending
              ? "L'application Android est en cours de préparation. Le lien de téléchargement sera publié ici."
              : 'Installez l’application Android et connectez-vous avec le rôle qui vous correspond.'}
          </p>

          <div className="download__cta">
            <DownloadButton />
            <a
              className="btn btn--ghost"
              href={config.repoUrl}
              target="_blank"
              rel="noreferrer noopener"
            >
              <Icon name="code" size={17} />
              Voir le code source
            </a>
          </div>

          <p className="download__meta">
            Version {config.apkVersion}
            {config.apkSizeMb ? ` · ${config.apkSizeMb} Mo` : ''} · Android 6.0 ou supérieur
          </p>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="footer">
      <div className="shell footer__inner">
        <div className="footer__copy">
          © {new Date().getFullYear()} {config.appName} — {config.tagline}
        </div>
        <nav className="footer__links" aria-label="Liens de pied de page">
          <a href={config.repoUrl} target="_blank" rel="noreferrer noopener">
            GitHub
          </a>
          <a href={config.apiHealthUrl} target="_blank" rel="noreferrer noopener">
            État de l’API
          </a>
          <a href={`mailto:${config.contactEmail}`}>Contact</a>
        </nav>
      </div>
    </footer>
  );
}

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Roles />
        <Features />
        <Lifecycle />
        <Download />
      </main>
      <Footer />
    </>
  );
}
