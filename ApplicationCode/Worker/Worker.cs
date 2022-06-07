using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;

namespace Worker
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IConfiguration _config;

        public Worker(ILogger<Worker> logger, IConfiguration config)
        {
            _logger = logger;
            _config = config;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var factory = new ConnectionFactory() { HostName = _config["AppSettings:RabbitMqHostName"] };
            using var connection = factory.CreateConnection();
            using var channel = connection.CreateModel();

            //We declare the queue in RabbitMQ. This operation is idempotent so if
            //this queue already exists, nothing happens
            channel.QueueDeclare(queue: _config["AppSettings:QueueName"],
                                    durable: false,
                                    exclusive: false,
                                    autoDelete: false,
                                    arguments: null);

            //We do this so that RabbitMQ only dispatches a message to this Worker when
            //it has ACKed its current message. If we don't do this, workers get allocated
            //work as it comes in on the queue, regardsless of whether their done with their
            //current work or not.
            channel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false);

            var consumer = new EventingBasicConsumer(channel);

            //This is where we define what happens when we receive a message
            consumer.Received += (model, ea) =>
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);
                Console.WriteLine($"Received request to make a {message} pizza. Starting job");

                //We simulate the pizza making process by simply waiting between 15 and 25 seconds
                Thread.Sleep(new Random().Next(15000, 25000));

                //Now the pizza-making is done we tell RabbitMQ that we're done by
                //sending an acknowledgement back
                channel.BasicAck(deliveryTag: ea.DeliveryTag, multiple: false);

                Console.WriteLine($"Pizza {message} ready, job done!");
            };

            //We hook the receiving logic up to the queue
            channel.BasicConsume(queue: _config["AppSettings:QueueName"],
                                    autoAck: false,
                                    consumer: consumer);

            Console.WriteLine($"Done setting up a listener on queue {_config["AppSettings:QueueName"]}");

            while (!stoppingToken.IsCancellationRequested)
            {
                //We check for cancellation every second and return from
                //our execute method when we get a cancellation request
                await Task.Delay(1000, stoppingToken);
            }
        }
    }
}