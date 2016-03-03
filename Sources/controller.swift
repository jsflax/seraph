import Foundation


class HttpController {
    static internal var actionRegistrants: [Action] = []

    final func register(actionContext: ActionContext,
                        handler: Request -> HttpMessage,
                        contentType: ContentType,
                        verbs: HttpVerb...) {
        HttpController.actionRegistrants += [Action(handler: handler,
                contentType: contentType,
                actionContext: actionContext,
                verbs: verbs)]
    }
}


internal class WsControllerUntyped {
    static internal var actionRegistrants: [Action] = []
}

class WsController {

    final func register(actionContext: ActionContext,
                        handler: Request -> WsMessage,
                        contentType: ContentType,
                        verbs: HttpVerb...) {
        WsControllerUntyped.actionRegistrants += [Action(handler: handler,
                contentType: contentType,
                actionContext: actionContext,
                verbs: verbs)]
    }
}
