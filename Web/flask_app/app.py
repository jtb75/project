'''Handlers to paint and make DB read/writes'''
import os
from flask import Flask, render_template, request, url_for, redirect
from pymongo import MongoClient
from bson.objectid import ObjectId
from flask_basicauth import BasicAuth


app = Flask(__name__)

app.config['BASIC_AUTH_USERNAME'] = 'user'
app.config['BASIC_AUTH_PASSWORD'] = 'password'
app.config['BASIC_AUTH_FORCE'] = True

basic_auth = BasicAuth(app)

client = MongoClient(
    'mongod', 27017, username=os.environ['DB_USER'], password=os.environ['DB_PASSWORD'])

# Initiate DB connection Mongo 'flask_db' database
db = client.flask_db

# Gather all todo items from 'todos' collection
todos = db.todos


@app.route('/', methods=('GET', 'POST'))
def index():
    '''Handles reloads and submissions for new todos'''
    if request.method == 'POST':
        content = request.form['content']
        degree = request.form['degree']
        todos.insert_one({'content': content, 'degree': degree})
        return redirect(url_for('index'))

    all_todos = todos.find()
    return render_template('index.html', todos=all_todos)


@app.post('/<id>/delete/')
def delete(id):
    '''Handles deletes of todos and redirects back to index'''
    todos.delete_one({"_id": ObjectId(id)})
    return redirect(url_for('index'))
