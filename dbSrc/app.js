'use strict'
const express = require('express')
const bodyParser = require('body-parser')
const cors = require('cors')
const awsServerlessExpressMiddleware = require('aws-serverless-express/middleware')
const app = express()
var helmet = require('helmet')
var elasticsearch = require('elasticsearch')
var client = elasticsearch.Client({
  host: '172.31.39.40:9200',
  log: 'info'
})

app.use(cors())
app.use(helmet())
app.use(bodyParser.json())
app.use(bodyParser.urlencoded({ extended: true }))
app.use(awsServerlessExpressMiddleware.eventContext())

app.get('/', (req, res) => {
    res.sendFile(`${__dirname}/index.html`)
})

// app.get('/ingredients', (req, res) => {
//     client.search({
//       "query": { "match_all": {} },
//       "size": 1
//     }).then(function (response) {
//       let ingredient = response.hits.hits
//       // console.log('Ingredient: ', ingredient)
//     }, function (error) {
//       console.trace(error.message)
//     })
//     res.json(ingredients)
// })

// app.get('/ingredients/:ingredientsId', (req, res) => {
//     console.log('request: ', req)
//     client.search({
//       q: req.params.ingredientsId,
//       size: 10
//     }).then(function (response) {
//       return res.status(201).json({data: response.hits.hits})
//     }, function (error) {
//       console.trace(error.message)
//       return res.status(404).json({error: error.message})
//     })
// })

app.post('/ingredients', (req, res) => {
    // const ingredient = {
    //     id: ++ingredientsIdCounter,
    //     name: req.body.name
    // }
    // ingredients.push(ingredient)
    // res.status(201).json(ingredient)

    // query format
    // '{
    //   "query": { "match": { "Description": "kale" } },
    //   "size": 1
    // }'

    // command format
    //curl https://tah21v2noa.execute-api.us-west-2.amazonaws.com/prod/ingredients -X POST -d '{"query": {"match": {"Description": "kale"}}, "size": 1}' --header 'content-type: application/json'
    // console.log('Request: ', req)
    // console.log('Request Body: ', req.body)
    // console.log('Query: ', req.body.query)
    // console.log('Size: ', req.body.size)
    const query = req.body.query
    const size = req.body.size
    const ingredient = query.match.Description
    client.search({
      body: {
        query: {
          "multi_match" : {
            "query":      ingredient,
            "fields" : ["Description"], 
            "type":       "best_fields",
            "operator":   "or"
          }
        },
        size: size
      }
    }).then(function (response) {
      console.log('Results: ', response.hits.hits)
      return res.status(201).json({data: response.hits.hits})
    }, function (error) {
      console.trace(error.message)
      return
    })
})

// app.put('/ingredients/:ingredientsId', (req, res) => {
//     const ingredient = getIngredientId(req.params.ingredientsId)

//     if (!ingredient) return res.status(404).json({})

//     ingredient.name = req.body.name
//     res.json(ingredient)
// })

// app.delete('/ingredients/:ingredientsId', (req, res) => {
//     const userIndex = getIngredientIndex(req.params.ingredientsId)

//     if(userIndex === -1) return res.status(404).json({})

//     ingredients.splice(userIndex, 1)
//     res.json(ingredients)
// })

// const getIngredientId = (ingredientsId) => ingredients.find(u => u.id === parseInt(ingredientsId))
// const getIngredientIndex = (ingredientsId) => ingredients.findIndex(u => u.id === parseInt(ingredientsId))

// // Ephemeral in-memory data store
// const ingredients = [{
//     id: 1,
//     name: 'Joe'
// }, {
//     id: 2,
//     name: 'Jane'
// }]
// let ingredientsIdCounter = ingredients.length

// The aws-serverless-express library creates a server and listens on a Unix
// Domain Socket for you, so you can remove the usual call to app.listen.
// app.listen(3000)

// Export your express server so you can import it in the lambda function.
module.exports = app
