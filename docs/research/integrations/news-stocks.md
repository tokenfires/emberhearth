# News & Stocks Integration Research

**Status:** Complete
**Priority:** Low-Medium
**Last Updated:** February 2, 2026

---

# Apple News

## User Value

| Capability | User Benefit |
|------------|--------------|
| News summaries | "What's happening today?" |
| Topic search | "News about AI" |
| Personalized digest | Morning news briefing |

## Technical Reality

**No API exists for Apple News.**

### What We Know

- No AppleScript dictionary
- No public framework
- No URL schemes for reading articles
- Apple News+ content is DRM-protected

### Workarounds

1. **General RSS feeds** - Not Apple News specific
2. **News API services** - NewsAPI.org, Google News API
3. **Web scraping** - Fragile, terms of service issues

### Alternative: Third-Party News APIs

```swift
// Using NewsAPI.org
func fetchTopHeadlines(category: String) async throws -> [NewsArticle] {
    let url = URL(string: "https://newsapi.org/v2/top-headlines?country=us&category=\(category)&apiKey=YOUR_KEY")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(NewsResponse.self, from: data)
    return response.articles
}
```

### Recommendation: **LOW** feasibility for Apple News specifically

Use general news APIs instead if news features are desired.

---

# Stocks

## User Value

| Capability | User Benefit |
|------------|--------------|
| Portfolio summary | "How are my stocks doing?" |
| Price alerts | "Tell me when AAPL hits $200" |
| Market overview | "How's the market today?" |
| Stock lookup | "What's Tesla's price?" |

## Technical Reality

**No API for Apple Stocks app.**

- No AppleScript support
- No framework access
- No URL schemes
- Portfolio data is private

### Alternative: Financial APIs

Several third-party APIs provide stock data:

| API | Free Tier | Notes |
|-----|-----------|-------|
| Yahoo Finance | Limited | Unofficial, may break |
| Alpha Vantage | 5 calls/min | Good documentation |
| Finnhub | 60 calls/min | Real-time data |
| Polygon.io | Limited | Professional grade |
| IEX Cloud | Limited | Clean API |

### Implementation with Alpha Vantage

```swift
class StocksService {
    private let apiKey = "YOUR_API_KEY"

    func getQuote(symbol: String) async throws -> StockQuote {
        let url = URL(string: "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(StockQuoteResponse.self, from: data).quote
    }

    func getDailyPrices(symbol: String) async throws -> [DailyPrice] {
        let url = URL(string: "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=\(symbol)&apikey=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseDailyPrices(data)
    }

    func searchSymbol(query: String) async throws -> [SymbolMatch] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "https://www.alphavantage.co/query?function=SYMBOL_SEARCH&keywords=\(encoded)&apikey=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SymbolSearchResponse.self, from: data).matches
    }
}

struct StockQuote: Codable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: String
    let volume: Int
}
```

### Market Indices

```swift
func getMarketOverview() async throws -> MarketOverview {
    async let sp500 = getQuote(symbol: "SPY")  // S&P 500 ETF
    async let nasdaq = getQuote(symbol: "QQQ") // Nasdaq ETF
    async let dow = getQuote(symbol: "DIA")    // Dow ETF

    return MarketOverview(
        sp500: try await sp500,
        nasdaq: try await nasdaq,
        dow: try await dow
    )
}
```

---

## EmberHearth Integration Design

### News Conversations

**User:** "What's in the news today?"
**EmberHearth:** "Here are today's top stories:

**Technology:**
- Apple announces new AI features at WWDC
- Microsoft reports record cloud revenue

**Business:**
- Fed signals potential rate cut in March
- Tesla deliveries exceed expectations

**World:**
- Climate summit reaches historic agreement

Want more details on any of these?"

### Stocks Conversations

**User:** "How's the market today?"
**EmberHearth:** "Market overview:
- S&P 500: 5,234 (+0.8%)
- Nasdaq: 16,892 (+1.2%)
- Dow Jones: 38,654 (+0.5%)

Markets are up on positive earnings reports."

**User:** "What's Apple's stock price?"
**EmberHearth:** "Apple (AAPL):
- Price: $189.45
- Change: +$2.30 (+1.23%)
- Volume: 52.3M shares

52-week range: $164.08 - $199.62"

**User:** "Send me a daily stock summary"
**EmberHearth:** "I'll send you a market summary each day at 4:30 PM (after market close). You can customize which stocks to track.

Current watchlist: AAPL, MSFT, GOOGL, AMZN

Want to add or remove any symbols?"

---

## Portfolio Tracking (User-Managed)

Since we can't access Apple Stocks portfolio:

```swift
struct UserPortfolio: Codable {
    var holdings: [Holding]

    struct Holding: Codable {
        let symbol: String
        let shares: Double
        let costBasis: Double
    }
}

// User tells EmberHearth their holdings
// EmberHearth stores locally and calculates performance
```

**User:** "Add 10 shares of NVDA at $850"
**EmberHearth:** "Added to your portfolio:
- NVDA: 10 shares @ $850/share ($8,500 total)

I'll track this for you. Say 'portfolio summary' anytime."

---

## Permissions Required

| Permission | Purpose |
|------------|---------|
| Network | API calls to financial services |
| (None else) | No Apple frameworks needed |

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No Apple News API | Can't read News app content | Use third-party news APIs |
| No Apple Stocks API | Can't read portfolio | User-managed watchlist |
| API rate limits | Limited free tier calls | Cache responses |
| Real-time data costs | Live quotes expensive | Use delayed quotes |
| API key management | Security concern | Store in Keychain |

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Stock quote lookup | Medium | Low |
| Market overview | Medium | Low |
| User watchlist | Medium | Low |
| News headlines | Low | Low |
| Portfolio tracking | Low | Medium |
| Price alerts | Low | Medium |

---

## Resources

### News APIs
- [NewsAPI.org](https://newsapi.org/)
- [Google News API](https://developers.google.com/news)
- [GNews API](https://gnews.io/)

### Financial APIs
- [Alpha Vantage](https://www.alphavantage.co/documentation/)
- [Finnhub](https://finnhub.io/docs/api)
- [IEX Cloud](https://iexcloud.io/docs/api/)
- [Polygon.io](https://polygon.io/docs/)
- [Yahoo Finance (unofficial)](https://github.com/ranaroussi/yfinance)

---

## Recommendation

**News: LOW** feasibility for Apple News integration
**Stocks: MEDIUM** feasibility using third-party APIs

Neither integrates with Apple's native apps, but both can provide value through external APIs:

1. News via NewsAPI or similar
2. Stocks via financial data APIs
3. User-managed watchlists stored locally

These are "nice to have" features that don't leverage Apple ecosystem uniquely but still provide assistant utility.
