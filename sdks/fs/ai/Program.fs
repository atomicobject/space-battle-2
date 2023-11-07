open System
open System.Net
open System.Net.Sockets
open System.Threading.Tasks
open System.Threading
open System.IO

// Function to handle a client
let rec handleClient ai (client: TcpClient) =
    let stream = client.GetStream()
    let reader = new StreamReader(stream)
    let writer = new StreamWriter(stream)

    // reading data
    let data = reader.ReadLineAsync().Result

    let updated, commands = AI.processUpdate ai data

    writer.WriteLineAsync(commands).Wait()
    writer.FlushAsync().Wait()
    // Continue to remain connected with the client
    handleClient updated client

// Function to accept clients
let rec acceptClients (listener: TcpListener) =
    let client = listener.AcceptTcpClientAsync().Result
    printfn "Connected to client!"

    try handleClient AI.InitAI client
    with e -> printfn "Disconnected from client!"

    acceptClients listener

let server port =
    // Set up a listener
    let listener = new TcpListener(IPAddress.Any, port)
    listener.Start()
    printfn "Listening on port %d..." port

    // Start accepting clients
    acceptClients listener

[<EntryPoint>]
let main argv =
    let port =
        match argv with
        | [| portStr |] -> Int32.Parse(portStr)
        | _ -> 9090

    let cts = new CancellationTokenSource()
    let token = cts.Token

    let listenerTask = Task.Factory.StartNew((fun () -> server port), token)

    // Wait for the listener to stop
    listenerTask.Wait()
    0
