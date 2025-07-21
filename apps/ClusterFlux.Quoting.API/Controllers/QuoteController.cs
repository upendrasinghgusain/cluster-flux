using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using System.ComponentModel.DataAnnotations;

namespace ClusterFlux.Quoting.API.Controllers
{

    [ApiController]
    [Route("api/[controller]")]
    public class QuoteController : ControllerBase
    {
        private readonly ILogger<QuoteController> _logger;
        private readonly IQuoteService _quoteService;

        public QuoteController(ILogger<QuoteController> logger, IQuoteService quoteService)
        {
            _logger = logger;
            _quoteService = quoteService;
        }

        [HttpPost]
        public ActionResult<QuoteResponse> CreateQuote([FromBody] QuoteRequest request)
        {
            try
            {
                _logger.LogInformation("Creating quote for customer {ClientId} and product {ProductName}",
                    request.ClientId, request.ProductName);
                var result = _quoteService.CreateQuote(request);

                var x = SimulateCPUStress();

                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("quotes")]
        public ActionResult<QuoteResponse> GetQuotes()
        {
            _logger.LogInformation("Retrieving all quotes");
            var result = _quoteService.GetQuotes();
            return Ok(result);
        }

        private double SimulateCPUStress()
        {
            var data = Enumerable.Range(1, 100000000).Select(i => i * i).ToList();
            var filtered = data.Where(x => x % 7 == 0).ToList();

            return filtered.Sum(x => Math.Sqrt(x));
        }
    }

    public class QuoteRequest
    {
        [Required]
        public Guid ClientId { get; set; }
        [Required]
        public string CustomerName { get; set; }
        [Required]
        public string ProductName { get; set; }
    }

    public class QuoteResponse
    {
        public string SubmissionId { get; set; }
        public string QuoteId { get; set; }
        public Guid ClientId { get; set; }
        public string CustomerName { get; set; }
        public string ProductName { get; set; }
        public decimal Premium { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public interface IQuoteService
    {
        QuoteResponse CreateQuote(QuoteRequest request);

        List<QuoteResponse> GetQuotes();
    }

    public class QuoteService : IQuoteService
    {
        private readonly IMemoryCache _cache;
        public QuoteService(IMemoryCache cache)
        {
            _cache = cache;
        }

        public QuoteResponse CreateQuote(QuoteRequest request)
        {
            if (request == null)
                throw new ArgumentNullException(nameof(request));

            if (request.ClientId == Guid.Empty)
                throw new ArgumentException("Invalid quote request, missing client Id");

            if (string.IsNullOrWhiteSpace(request.CustomerName))
                throw new ArgumentException("Invalid quote request, missing customer name");

            if (string.IsNullOrWhiteSpace(request.ProductName))
                throw new ArgumentException("Invalid quote request, missing product name");

            var cacheEntryOptions = new MemoryCacheEntryOptions()
                .SetSlidingExpiration(TimeSpan.FromMinutes(100));

            var response = new QuoteResponse
            {
                SubmissionId = Guid.NewGuid().ToString(),
                QuoteId = Guid.NewGuid().ToString(),
                CustomerName = request.CustomerName,
                ClientId = request.ClientId,
                ProductName = request.ProductName,
                Premium = 123.45m
            };

            var quotes = GetCachedQuotes();
            quotes.Add(response);

            _cache.Set("quote-cache", quotes, cacheEntryOptions);

            return response;
        }

        public List<QuoteResponse> GetQuotes()
        {
            return GetCachedQuotes();
        }

        private List<QuoteResponse> GetCachedQuotes()
        {
            if (_cache.TryGetValue("quote-cache", out List<QuoteResponse> quotes))
            {
                return quotes;
            }
            // If not found in cache, return an empty list
            return new List<QuoteResponse>();
        }
    }
}
