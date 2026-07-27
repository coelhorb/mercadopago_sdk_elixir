[
  smells: [
    # These modules share a CRUD shape by coincidence of the REST API, not by
    # contract: they are distinct resources and are never selected dynamically.
    # A behaviour here would buy no polymorphism, and the @spec on each function
    # already documents the signature.
    behaviour_candidate: [
      ignore: [paths: ["lib/mercadopago/merchant_order.ex"]]
    ]
  ]
]
