'use strict'
const express = require('express')
const bodyParser = require('body-parser')
const cors = require('cors')
const awsServerlessExpressMiddleware = require('aws-serverless-express/middleware')
const app = express()
var helmet = require('helmet')

app.use(cors())
app.use(helmet())
app.use(bodyParser.json())
app.use(bodyParser.urlencoded({ extended: true }))
app.use(awsServerlessExpressMiddleware.eventContext())

app.get('/', (req, res) => {
    res.sendFile(`${__dirname}/index.html`)
})

app.get('/oembed', (req, res) => {
  const url = req.query.url
  const userId = req.query.user
  const labelId = req.query.label
  if (userId && labelId) {
    const url = "http://label.inphood.com/?embed=true&user="+userId+"&label="+labelId
    const html = "<object width=\"400\" height=\"600\"><embed src=\""+url+"\" width=\"400\" height=\"600\"></embed></object>"
    return res.status(201).json({
      "version": "1.0",
      "type": "rich",
      "width": 400,
      "height": 600,
      "title": labelId,
      "url": url,
      "author_name": userId,
      "author_url": "http://www.label.inphood.com/",
      "provider_name": "inphood",
      "provider_url": "http://www.inphood.com/",
      "html": html
    })
  }
  else
    return res.status(404).json({error: "Invalid Label"})
})

// app.post('/ingredients', (req, res) => {
//   const elasticsearch = require('elasticsearch')
//   const client = elasticsearch.Client({
//     host: '172.31.39.40:9200',
//     log: 'info'
//   })
//   const query = req.body.query
//   const size = req.body.size
//   const ingredient = query.match.Description
//   client.search({
//     body: {
//       query: {
//         "multi_match" : {
//           "query":      ingredient,
//             "fields" : ["Description"], 
//           "type":       "best_fields",
//           "operator":   "or"
//         }
//       },
//       size: size
//     }
//   }).then(function (response) {
//     console.log('Results: ', response.hits.hits)
//     return res.status(201).json({data: response.hits.hits})
//   }, function (error) {
//     console.trace(error.message)
//     return
//   })
// })

app.post('/ingredients', (req, res) => {
  const elasticsearch = require('elasticsearch')
  const client = elasticsearch.Client({
    host: '172.31.39.40:9200',
    log: 'info'
  })
  const query = req.body.query
  const size = req.body.size
  const ingredient = query.match.Description

  const iterationFourSearch = {
    body: {
      query: {
        "multi_match": {
          "query": ingredient,
          "fields": ["Description"],
          "type": "best_fields",
          "operator" : "or"
        }
      },
      size: size
    }
  }

  const iterationFiveSearch = {
    body: {
      query : {
        bool : {
          must : [
            {
              multi_match : {
                query : ingredient,
                fields : ["Description"],
                type : "best_fields",
                operator : "or"
              }
            }
          ],
          should : [
            { span_first : {
                match: { span_term : { Description : ingredient } },
                end : 1
              }
            },
            { match : { Description : "raw" } },
            { match : { Description : "tap" } } 
          ] 
        }
      },
      size: size,
      highlight : {
        fields : {
          Description : {}
        }
      }
    }
  }
  
  client.search(iterationFiveSearch)
    .then(function (response) {
      console.log('Results: ', response.hits.hits)
      return res.status(201).json({data: response.hits.hits})
    }, function (error) {
    console.trace(error.message)
    return
  })
})

// Export your express server so you can import it in the lambda function.
module.exports = app
