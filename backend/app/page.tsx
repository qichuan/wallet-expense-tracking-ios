export default function Home() {
  return (
    <main style={{ fontFamily: "system-ui, sans-serif", padding: "3rem", lineHeight: 1.6 }}>
      <h1>CardPulse Category API</h1>
      <p>
        Transaction category inference for the CardPulse iOS app. The only endpoint is{" "}
        <code>POST /api/categorize</code>, which requires a bearer token.
      </p>
    </main>
  );
}
