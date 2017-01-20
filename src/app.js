'use strict'
const express = require('express')
const bodyParser = require('body-parser')
const cors = require('cors')
const awsServerlessExpressMiddleware = require('aws-serverless-express/middleware')
const app = express()
var helmet = require('helmet')
var elasticsearch = require('elasticsearch')

app.use(cors())
app.use(helmet())
app.use(bodyParser.json())
app.use(bodyParser.urlencoded({ extended: true }))
app.use(awsServerlessExpressMiddleware.eventContext())

app.get('/', (req, res) => {
    res.sendFile(`${__dirname}/index.html`)
})

app.get('/ingredients', (req, res) => {
    res.json(ingredients)
})

app.get('/ingredients/:ingredientsId', (req, res) => {
    const user = getIngredientId(req.params.ingredientsId)

    if (!user) return res.status(404).json({})

    return res.json(user)
})

app.post('/ingredients', (req, res) => {
    const user = {
        id: ++ingredientsIdCounter,
        name: req.body.name
    }
    ingredients.push(user)
    res.status(201).json(user)
})

app.put('/ingredients/:ingredientsId', (req, res) => {
    const user = getIngredientId(req.params.ingredientsId)

    if (!user) return res.status(404).json({})

    user.name = req.body.name
    res.json(user)
})

app.delete('/ingredients/:ingredientsId', (req, res) => {
    const userIndex = getIngredientIndex(req.params.ingredientsId)

    if(userIndex === -1) return res.status(404).json({})

    ingredients.splice(userIndex, 1)
    res.json(ingredients)
})

const getIngredientId = (ingredientsId) => ingredients.find(u => u.id === parseInt(ingredientsId))
const getIngredientIndex = (ingredientsId) => ingredients.findIndex(u => u.id === parseInt(ingredientsId))

// Ephemeral in-memory data store
const ingredients = [{
    id: 1,
    name: 'Joe'
}, {
    id: 2,
    name: 'Jane'
}]
let ingredientsIdCounter = ingredients.length

// The aws-serverless-express library creates a server and listens on a Unix
// Domain Socket for you, so you can remove the usual call to app.listen.
// app.listen(3000)

// Export your express server so you can import it in the lambda function.
module.exports = app
