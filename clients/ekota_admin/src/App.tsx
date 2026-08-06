const stats = [
  { label: 'Active districts', value: '128' },
  { label: 'Pending reviews', value: '24' },
  { label: 'Synced today', value: '9.4k' },
]

const panels = [
  {
    title: 'Verification queue',
    copy: 'Review incoming requests, approve records, and keep the public catalog in sync.',
  },
  {
    title: 'Operational snapshot',
    copy: 'Track activity, publishing status, and system health from one command center.',
  },
  {
    title: 'Content controls',
    copy: 'Manage featured collections, announcements, and administrative workflows quickly.',
  },
]

function App() {
  return (
    <main className="shell">
      <section className="hero">
        <div className="hero__copy">
          <p className="eyebrow">Ekota Admin</p>
          <h1>Coordinate the platform from a focused admin workspace.</h1>
          <p className="lede">
            A clean React starter for managing records, reviewing submissions, and monitoring
            activity across the Ekota ecosystem.
          </p>
          <div className="actions">
            <button type="button">Open dashboard</button>
            <button type="button" className="secondary">
              View queue
            </button>
          </div>
        </div>

        <div className="hero__panel">
          <div className="panel__header">
            <span>Live status</span>
            <span className="badge">Healthy</span>
          </div>
          <div className="stats">
            {stats.map((stat) => (
              <article key={stat.label}>
                <strong>{stat.value}</strong>
                <span>{stat.label}</span>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="grid">
        {panels.map((panel) => (
          <article key={panel.title} className="card">
            <h2>{panel.title}</h2>
            <p>{panel.copy}</p>
          </article>
        ))}
      </section>
    </main>
  )
}

export default App
