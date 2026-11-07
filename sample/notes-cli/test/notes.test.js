'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { add, markDone, remove, format } = require('../src/notes.js');

test('add gives the next id and starts not done', () => {
  const notes = add(add([], 'first'), 'second');
  assert.deepEqual(notes, [
    { id: 1, text: 'first', done: false },
    { id: 2, text: 'second', done: false },
  ]);
});

test('markDone sets done for one id only', () => {
  const notes = markDone(add(add([], 'a'), 'b'), 2);
  assert.equal(notes[0].done, false);
  assert.equal(notes[1].done, true);
});

test('remove drops the id and keeps the others', () => {
  const notes = remove(add(add([], 'a'), 'b'), 1);
  assert.deepEqual(notes, [{ id: 2, text: 'b', done: false }]);
});

test('format shows an empty list and marks done notes', () => {
  assert.equal(format([]), 'No notes.');
  assert.equal(format([{ id: 1, text: 'x', done: true }]), '1. [x] x');
});
