using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading;
using System.Threading.Tasks;

namespace ai
{
    class Program
    {
        static void Main(string[] args)
        {
            var port = 9090;
            if (args.Length > 0)
            {
                int n;
                if (int.TryParse(args[0], out n))
                {
                    port = n;
                }
            }

            CancellationTokenSource cancellationTokenSource = new CancellationTokenSource();
            CancellationToken token = cancellationTokenSource.Token;

            // todo: make this work:
            Console.CancelKeyPress += delegate { cancellationTokenSource.Cancel(); };

            var theTask = Task.Run(async () =>
            {
                await MainLoop(args, cancellationTokenSource, port);
            }, token);

            theTask.Wait();
            Console.WriteLine("");

            Console.Out.Flush();
        }

        private static async Task MainLoop(string[] args, CancellationTokenSource tokenSource, int port)
        {
            System.Net.Sockets.TcpClient socket = null;
            System.Net.Sockets.TcpListener listener = null;

            listener = new System.Net.Sockets.TcpListener(IPAddress.Any, port);
            listener.Start();

            // *** starting to listen to socket

            while (!tokenSource.Token.WaitHandle.WaitOne(1))
            {
                Console.WriteLine("listening on port " + port);
                try
                {
                    socket = await listener.AcceptTcpClientAsync();

                    Console.WriteLine("Connected!");

                    var ai = new Ai();

                    using (var stream = socket.GetStream())
                    using (var sr = new StreamReader(stream))
                    using (var sw = new StreamWriter(stream))
                    {
                        while (!tokenSource.Token.WaitHandle.WaitOne(1))
                        {
                            string line = await sr.ReadLineAsync();

                            Console.WriteLine("received "+line);

                            var commands = ai.GoJson(line);

                            await sw.WriteAsync(commands);
                            await sw.FlushAsync();
                        } 
                    }
                }
                catch (Exception e)
                {
                    Console.Error.WriteLine("\n" + e.Message);
                    socket?.Dispose();
                }

            }
            socket?.Dispose();
        }

    }

}