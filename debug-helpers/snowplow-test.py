# This script will require you to have already installed the snowplow dependencies in your local python environment
# If you just need a single test event and don't care about the schema, use snowplow-test.sh instead

from snowplow_tracker import SelfDescribingJson
from snowplow_tracker import Emitter, Tracker

event_data = {
        "link_id": "my-test-link"
    }
event = SelfDescribingJson(
        "iglu:com.vida.test/simple_event/jsonschema/1-0-0",
        event_data,
    )
emitter = Emitter(
            "XXX.ngrok.io/snowplow",  # host
            protocol="https",  # protocol
            method="post",   # use POST because some events are large
            buffer_size=1,
        )
app_id = "docker-local-dev-test"
tracker = Tracker(emitter, app_id=app_id)

tracker.track_self_describing_event(event)
