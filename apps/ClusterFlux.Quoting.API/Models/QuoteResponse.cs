namespace ClusterFlux.Quoting.API.Models
{
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
}
