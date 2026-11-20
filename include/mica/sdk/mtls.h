// Connect to the Mica network with mutual TLS.
//
// Every connection to Mica uses mutual TLS: the client presents a certificate issued by Mica and verifies Mica's
// server certificate (including its host name) against the root certificate authority Mica provides.
#pragma once

#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>

#include <grpcpp/grpcpp.h>

namespace mica::sdk {

// PEM material for a mutual TLS connection to Mica.
struct MtlsCredentials {
  std::string certificate_authorities;  // root certificate(s) used to verify Mica's server certificate
  std::string certificate;              // the client certificate chain issued by Mica
  std::string key;                      // the private key for `certificate`

  // Reads the credentials from PEM files on disk. Throws std::runtime_error if a file cannot be read.
  static MtlsCredentials FromFiles(const std::string& certificate_authorities_file, const std::string& certificate_file,
                                   const std::string& key_file) {
    return {Read(certificate_authorities_file), Read(certificate_file), Read(key_file)};
  }

 private:
  static std::string Read(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) throw std::runtime_error("unable to read " + path);
    std::ostringstream contents;
    contents << in.rdbuf();
    return contents.str();
  }
};

// The gRPC channel credentials for the given mutual TLS material.
inline std::shared_ptr<grpc::ChannelCredentials> ChannelCredentials(const MtlsCredentials& credentials) {
  grpc::SslCredentialsOptions options;
  options.pem_root_certs = credentials.certificate_authorities;
  options.pem_cert_chain = credentials.certificate;
  options.pem_private_key = credentials.key;
  return grpc::SslCredentials(options);
}

// Opens a channel to `target` (for example "api.example.mica.io:443") with mutual TLS. Pass the channel to any
// generated client, for example `mica::member::ping::v1::PingService::NewStub(channel)`.
inline std::shared_ptr<grpc::Channel> CreateMtlsChannel(const std::string& target, const MtlsCredentials& credentials) {
  return grpc::CreateChannel(target, ChannelCredentials(credentials));
}

}  // namespace mica::sdk
