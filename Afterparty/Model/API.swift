//
//  API.swift
//  Afterparty
//
//  Created by David Okun on 7/5/20.
//  Copyright © 2020 David Okun. All rights reserved.
//

import Foundation
import Combine
import afterparty_models_swift

struct Resource<A> {
  let url: URL
  let parse: (Data) throws -> A
}

extension Resource where A: Decodable {
  init(url: URL) {
    self.url = url
    self.parse = { data in
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(A.self, from: data)
    }
  }
}

class AfterpartyAPI {
  private var session = URLSession(configuration: .default)
  private let apiQueue = DispatchQueue(label: "AfterpartyAPI", qos: .default, attributes: .concurrent)
    
  enum Error: LocalizedError, Identifiable {
    var id: String { localizedDescription }
    
    case addressUnreachable(URL)
    case invalidResponse
    
    var errorDescription: String? {
      switch self {
        case .addressUnreachable(let url): return "\(url.absoluteString) is not reachable."
        case .invalidResponse: return "The server response is invalid."
      }
    }
  }
  
  enum Endpoint {
    case mockEvents
    case mockUsers
    case mockLocations
    case hello(String?)
    
    fileprivate var url: URL {
      switch self {
        case .hello(let name):
          if let name = name {
            return EnvironmentVariables.rootURL.appendingPathComponent("hello").appendingPathComponent(name)
          } else {
            return EnvironmentVariables.rootURL.appendingPathComponent("hello")
          }
        case .mockEvents:
          return EnvironmentVariables.rootURL.appendingPathComponent("mock/events")
        case .mockUsers:
          return EnvironmentVariables.rootURL.appendingPathComponent("mock/users")
        case .mockLocations:
          return EnvironmentVariables.rootURL.appendingPathComponent("mock/locations")
      }
    }
  }
    
  func load<A>(resource: Resource<A>) -> AnyPublisher<A, Error> {
    session
      .dataTaskPublisher(for: resource.url)
      .receive(on: apiQueue)
      .tryMap { try resource.parse($0.data) }
      .mapError { error in
        switch error {
          case is URLError:
            return Error.addressUnreachable(resource.url)
          default:
            return Error.invalidResponse
        }
      }
      .eraseToAnyPublisher()
    }
  
  func getHelloResponse(for name: String?) -> AnyPublisher<String, Error> {
    let resource = Resource<String>(url: Endpoint.hello(name).url)
    return load(resource: resource)
  }
  
  func getMockEvents() -> AnyPublisher<[Event], Error> {
    let resource = Resource<[Event]>(url: Endpoint.mockLocations.url)
    return load(resource: resource)
  }
  
  func getMockLocations() -> AnyPublisher<[Location], Error> {
    let resource = Resource<[Location]>(url: Endpoint.mockLocations.url)
    return load(resource: resource)
  }
  
  func getMockUsers() -> AnyPublisher<[User], Error> {
    let resource = Resource<[User]>(url: Endpoint.mockUsers.url)
    return load(resource: resource)
  }
}
