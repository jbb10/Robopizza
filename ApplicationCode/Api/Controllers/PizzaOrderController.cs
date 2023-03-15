using Microsoft.AspNetCore.Mvc;
using RabbitMQ.Client;
using System.Text;

namespace Api.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class PizzaOrderController : ControllerBase
    {
        private readonly ILogger<PizzaOrderController> _logger;
        private readonly IConfiguration _config;

        public PizzaOrderController(ILogger<PizzaOrderController> logger, IConfiguration config)
        {
            _logger = logger;
            _config = config;
        }

        [HttpPost]
        public string CreateJob(PizzaType pizzaType)
        {
            _logger.LogInformation($"Got a request for making a {pizzaType} pizza");

            //We need an ID for the job so we generate a UNIX timestamp to use as ID, e.g. 1655984608
            var jobId = DateTimeOffset.Now.ToUnixTimeSeconds();

            //Push message on queue to create job
            _logger.LogInformation($"Pushing {pizzaType} pizza job request to job queue");
            var factory = new ConnectionFactory() { HostName = _config["AppSettings:RabbitMqHostName"] };
            using (var connection = factory.CreateConnection())
            using (var channel = connection.CreateModel())
            {
                channel.QueueDeclare(queue: _config["AppSettings:QueueName"],
                                     durable: false,
                                     exclusive: false,
                                     autoDelete: false,
                                     arguments: null);

                var body = Encoding.UTF8.GetBytes(pizzaType.ToString());

                channel.BasicPublish(exchange: "",
                                     routingKey: _config["AppSettings:QueueName"],
                                     basicProperties: null,
                                     body: body);
            }

            _logger.LogInformation($"Successfully created job with ID {jobId}");
            return $"Successfully created job with ID {jobId}";
        }
    }
}