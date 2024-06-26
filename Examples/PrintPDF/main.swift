import Foundation
import IppClient

let httpClient = HTTPClient(configuration: .init(certificateVerification: .none))

let printer = IppPrinter(
    httpClient: httpClient,
    uri: "ipps://macmini.local/printers/EPSON_XP_7100_Series"
)

let attributesResponse = try await printer.getPrinterAttributes()

if let printerName = attributesResponse[printer: \.printerName],
   let printerState = attributesResponse[printer: \.printerState],
   let printerStateReasons = attributesResponse[printer: \.printerStateReasons]
{
    print("Printing on \(printerName) in state \(printerState), state reasons \(printerStateReasons)")
} else {
    print("Could not read printer attributes, status code \(attributesResponse.statusCode)")
}

let pdf = try Data(contentsOf: URL(fileURLWithPath: "Examples/PrintPDF/hi_mom.pdf"))

let response = try await printer.printJob(
    documentFormat: "application/pdf",
    data: .bytes(pdf)
)

guard response.statusCode == .successfulOk, let jobId = response[job: \.jobId] else {
    print("Print job failed with status \(response.statusCode)")
    try httpClient.syncShutdown()
    exit(1)
}

let job = printer.job(jobId)

while true {
    let response = try await job.getJobAttributes(requestedAttributes: [.jobState])
    guard let jobState = response[job: \.jobState] else {
        print("Failed to get job state")
        try httpClient.syncShutdown()
        exit(1)
    }

    switch jobState {
    case .aborted, .canceled, .completed:
        print("Job ended with state \(jobState)")
        try httpClient.syncShutdown()
        exit(0)
    default:
        print("Job state is \(jobState)")
    }

    try await Task.sleep(nanoseconds: 3_000_000_000)
}
