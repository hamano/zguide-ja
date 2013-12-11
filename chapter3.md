# リクエスト・応答パターンの応用
In Chapter 2 - Sockets and Patterns we worked through the basics of using ØMQ by developing a series of small applications, each time exploring new aspects of ØMQ. We'll continue this approach in this chapter as we explore advanced patterns built on top of ØMQ's core request-reply pattern.

We'll cover:

 * How the request-reply mechanisms work
 * How to combine REQ, REP, DEALER, and ROUTER sockets
 * How ROUTER sockets work, in detail
 * The load balancing pattern
 * Building a simple load balancing message broker
 * Designing a high-level API for ØMQ
 * Building an asynchronous request-reply server
 * A detailed inter-broker routing example

## リクエスト・応答のメカニズム
We already looked briefly at multipart messages. Let's now look at a major use case, which is reply message envelopes. An envelope is a way of safely packaging up data with an address, without touching the data itself. By separating reply addresses into an envelope we make it possible to write general purpose intermediaries such as APIs and proxies that create, read, and remove addresses no matter what the message payload or structure is.

In the request-reply pattern, the envelope holds the return address for replies. It is how a ØMQ network with no state can create round-trip request-reply dialogs.

When you use REQ and REP sockets you don't even see envelopes; these sockets deal with them automatically. But for most of the interesting request-reply patterns, you'll want to understand envelopes and particularly ROUTER sockets. We'll work through this step-by-step.

### 単純な応答パケット
A request-reply exchange consists of a request message, and an eventual reply message. In the simple request-reply pattern, there's one reply for each request. In more advanced patterns, requests and replies can flow asynchronously. However, the reply envelope always works the same way.

The ØMQ reply envelope formally consists of zero or more reply addresses, followed by an empty frame (the envelope delimiter), followed by the message body (zero or more frames). The envelope is created by multiple sockets working together in a chain. We'll break this down.

We'll start by sending "Hello" through a REQ socket. The REQ socket creates the simplest possible reply envelope, which has no addresses, just an empty delimiter frame and the message frame containing the "Hello" string. This is a two-frame message.

![Request with Minimal Envelope](images/fig26.svg)

The REP socket does the matching work: it strips off the envelope, up to and including the delimiter frame, saves the whole envelope, and passes the "Hello" string up the application. Thus our original Hello World example used request-reply envelopes internally, but the application never saw them.

If you spy on the network data flowing between hwclient and hwserver, this is what you'll see: every request and every reply is in fact two frames, an empty frame and then the body. It doesn't seem to make much sense for a simple REQ-REP dialog. However you'll see the reason when we explore how ROUTER and DEALER handle envelopes.

### The Extended Reply Envelope
### What's This Good For?
### Recap of Request-Reply Sockets

## Request-Reply Combinations
### The REQ to REP Combination
### The DEALER to REP Combination
### The REQ to ROUTER Combination
### The DEALER to ROUTER Combination
### The DEALER to DEALER Combination
### The ROUTER to ROUTER Combination
### Invalid Combinations

## Exploring ROUTER Sockets
### Identities and Addresses
### ROUTER Error Handling

## The Load Balancing Pattern
### ROUTER Broker and REQ Workers
### ROUTER Broker and DEALER Workers
### A Load Balancing Message Broker

## A High-Level API for ØMQ
### Features of a Higher-Level API
### The CZMQ High-Level API

## The Asynchronous Client/Server Pattern

## Worked Example: Inter-Broker Routing
### Establishing the Details
### Architecture of a Single Cluster
### Scaling to Multiple Clusters
### Federation Versus Peering
### The Naming Ceremony
### Prototyping the State Flow
### Prototyping the Local and Cloud Flows
### Putting it All Together
