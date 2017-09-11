package com.atomicobject.rts;
import java.net.ServerSocket;
import java.net.Socket;


public class Main {
	
	@SuppressWarnings("resource")
	public static void main(String[] args) {
		int port = args.length > 0 ? parsePort(args[0]) : 9090;
		try {
			ServerSocket serverSocket = new ServerSocket(port);
			while (true) {
				Socket clientSocket = serverSocket.accept();
				new Client(clientSocket).start();	
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	private static int parsePort(String port) {
		return Integer.parseInt(port);
	}
}
