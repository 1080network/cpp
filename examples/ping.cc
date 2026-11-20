// Connects to Mica with mutual TLS and calls Ping, a good first check that your certificates and network path work.
//
//   mica_ping api.example.mica.io:443 rootca.crt client.crt client.key
#include <chrono>
#include <iostream>

#include "mica/member/ping/v1/ping_service.grpc.pb.h"
#include "mica/sdk/mtls.h"

int main(int argc, char** argv) {
  if (argc != 5) {
    std::cerr << "usage: mica_ping <host:port> <rootca.crt> <client.crt> <client.key>\n";
    return 1;
  }
  auto credentials = mica::sdk::MtlsCredentials::FromFiles(argv[2], argv[3], argv[4]);
  auto stub = mica::member::ping::v1::PingService::NewStub(mica::sdk::CreateMtlsChannel(argv[1], credentials));

  grpc::ClientContext context;
  context.set_deadline(std::chrono::system_clock::now() + std::chrono::seconds(15));
  mica::member::ping::v1::PingResponse response;
  auto status = stub->Ping(&context, mica::member::ping::v1::PingRequest(), &response);
  if (!status.ok()) {
    std::cerr << "ping failed: " << status.error_message() << "\n";
    return 1;
  }
  std::cout << "status=" << mica::member::ping::v1::PingResponse::Status_Name(response.status())
            << " service=" << response.service_type() << " version=" << response.build_version() << "\n";
  return 0;
}
