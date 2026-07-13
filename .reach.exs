[
  smells: [
    # These modules already implement Mercadopago.Resource but represent distinct API resources.
    behaviour_candidate: [
      ignore: [paths: ["lib/mercadopago/merchant_order.ex"]]
    ]
  ]
]
