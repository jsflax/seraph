import Foundation

enum HttpVerb: String {
case GET = "GET"
case POST = "POST"
case PUT = "PUT"
case PATCH = "PATCH"
case DELETE = "DELETE"

     static let values = [GET, POST, PUT, PATCH, DELETE]
}

enum ContentType: String {
    case NoneType = ""
    case AllType = "*/*"
    case ApplicationOctetStream = "application/octet-stream"
    case ApplicationJson = "application/json"
    case ApplicationFormUrlEncoded = "application/x-www-form-urlencoded"

    case MultipartFormData = "multipart/form-data"

    case TextHtml = "text/html"
    case TextJavascript = "text/javascript"
    case TextCss = "text/css"

    case ImageWebp = "image/webp"
    case ImagePng = "image/png"
    case ImagePngBase64 = "image/png;base64"
    case ImageIco = "image/ico"

    case FontOpenType = "application/x-font-opentype"
    case FontTrueType = "application/x-font-truetype"

    static let values = [
               NoneType,
               AllType,
               ApplicationOctetStream,
               ApplicationJson,
               ApplicationFormUrlEncoded,
               MultipartFormData,
               TextHtml,
               TextJavascript,
               TextCss,
               ImageWebp,
               ImagePng,
               ImagePngBase64,
               ImageIco,
               FontOpenType,
               FontTrueType
           ]
}
