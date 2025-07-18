using System.ComponentModel.DataAnnotations;

namespace ClusterFlux.Quoting.API.Models
{
    public class QuoteRequest
    {
        [Required]
        public Guid ClientId { get; set; }
        [Required]
        public string CustomerName { get; set; }
        [Required]
        public string ProductName { get; set; }
    }
}
