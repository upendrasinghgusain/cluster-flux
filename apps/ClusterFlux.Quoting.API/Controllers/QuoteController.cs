using ClusterFlux.Quoting.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;

namespace ClusterFlux.Quoting.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class QuoteController : ControllerBase
    {
        private readonly ILogger<QuoteController> _logger;

        public QuoteController(ILogger<QuoteController> logger)
        {
            _logger = logger;
        }

        [HttpPost]
        public ActionResult<QuoteResponse> CreateQuote([FromBody] QuoteRequest request)
        {
            _logger.LogInformation("Creating quote for customer {ClientId} and product {ProductName}",
                   request.ClientId, request.ProductName);
            try
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

                return response;
            }
            catch (ArgumentException ex)
            {
                _logger.LogError(ex, "Error creating quote: {Message}", ex.Message);
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("quotes")]
        public ActionResult<QuoteResponse> GetQuotes()
        {
            _logger.LogInformation("Retrieving all quotes");

            var quotes = new List<QuoteResponse>
                {
                    new QuoteResponse
                    {
                        SubmissionId = Guid.NewGuid().ToString(),
                        QuoteId = Guid.NewGuid().ToString(),
                        CustomerName = "John Doe",
                        ProductName = "Product A",
                        Premium = 100.00m
                    },
                    new QuoteResponse
                    {
                        SubmissionId = Guid.NewGuid().ToString(),
                        QuoteId = Guid.NewGuid().ToString(),
                        CustomerName = "Jane Smith",
                        ProductName = "Product B",
                        Premium = 200.00m
                    },
                    new QuoteResponse
                    {
                        SubmissionId = Guid.NewGuid().ToString(),
                        QuoteId = Guid.NewGuid().ToString(),
                        CustomerName = "Alice Johnson",
                        ProductName = "Product C",
                        Premium = 150.00m
                    }
                };

            return Ok(quotes);
        }
    }
}
