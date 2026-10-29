import test from 'node:test';
import assert from 'node:assert/strict';
import { BridgeStore } from '../store.mjs';
test('Telegram update IDs deduplicate',()=> {
 const s=new BridgeStore();
 assert.equal(s.enqueue({updateId:42,chatId:5,userId:5,text:'one'}).created,true);
 assert.equal(s.enqueue({updateId:42,chatId:5,userId:5,text:'duplicate'}).created,false);
 assert.equal(s.status().counts.queued,1);s.close();
});
test('Listener claims and replies only to bound chat',()=> {
 const s=new BridgeStore();s.enqueue({updateId:43,chatId:123,userId:123,text:'hello'});
 s.activate('listener-aaa');assert.equal(s.claim('listener-bbb').error,'another_listener_active');
 const {event}=s.claim('listener-aaa');assert.equal(event.text,'hello');
 assert.equal(s.markSubmitted(event.id,'wrong').ok,false);
 assert.equal(s.markSubmitted(event.id,event.leaseId).ok,true);
 assert.equal(s.beginReply(event.id).chatId,'123');s.finishReply(event.id,'answer',true);
 assert.equal(s.event(event.id).status,'replied');
 assert.equal(s.beginReply(event.id).error,'already_replied');s.close();
});
test('Failed lease can be released',()=> {
 const s=new BridgeStore();s.enqueue({updateId:51,chatId:9,userId:9,text:'hello'});
 s.activate('listener-ccc');const {event}=s.claim('listener-ccc');
 assert.equal(s.release(event.id,'bad').released,false);
 assert.equal(s.release(event.id,event.leaseId).released,true);
 assert.equal(s.status().counts.queued,1);s.close();
});
test('Submitting requires explicit retry',()=> {
 const s=new BridgeStore();s.enqueue({updateId:52,chatId:9,userId:9,text:'hello'});
 s.activate('listener-ddd');const {event}=s.claim('listener-ddd');
 s.markSubmitted(event.id,event.leaseId);
 assert.equal(s.claim('listener-ddd').event,null);
 assert.equal(s.retry(event.id).retried,true);
 assert.equal(s.retry(event.id).retried,false);s.close();
});
test('Invalid content rejected',()=> {
 const s=new BridgeStore();
 assert.throws(()=>s.enqueue({updateId:1,chatId:1,userId:1,text:'x'.repeat(4097)}));
 assert.throws(()=>s.activate('x'));s.close();
});
