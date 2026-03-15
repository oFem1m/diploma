import asyncio
import pytest
from task_queue.job import Job, JobState
from task_queue.job_queue import JobQueue, QueueOverflowError


@pytest.fixture
def queue():
    return JobQueue(max_size=5)


class TestJob:
    def test_initial_state(self):
        job = Job(client_req_id="req-1", payload={})
        assert job.state == JobState.QUEUED
        assert job.job_id.startswith("job-")
        assert not job.is_terminal

    def test_state_transitions(self):
        job = Job(client_req_id="req-1", payload={})
        job.mark_started()
        assert job.state == JobState.RUNNING
        assert job.started_at is not None

        job.mark_succeeded({"best_f": 0.1})
        assert job.state == JobState.SUCCEEDED
        assert job.is_terminal
        assert job.result == {"best_f": 0.1}

    def test_cancel(self):
        job = Job(client_req_id="req-1", payload={})
        job.mark_cancelled()
        assert job.state == JobState.CANCELLED
        assert job.is_terminal
        assert job.cancel_event.is_set()

    def test_timeout(self):
        job = Job(client_req_id="req-1", payload={})
        job.mark_timeout()
        assert job.state == JobState.TIMEOUT
        assert job.is_terminal

    def test_failed(self):
        job = Job(client_req_id="req-1", payload={})
        job.mark_failed("something broke")
        assert job.state == JobState.FAILED
        assert job.error == "something broke"


class TestJobQueue:
    @pytest.mark.asyncio
    async def test_submit_and_get(self, queue):
        job, is_new = await queue.submit({"test": True}, "req-1")
        assert is_new is True
        assert job.state == JobState.QUEUED

        next_job = await queue.get_next()
        assert next_job.job_id == job.job_id

    @pytest.mark.asyncio
    async def test_idempotency(self, queue):
        job1, new1 = await queue.submit({}, "req-same")
        job2, new2 = await queue.submit({}, "req-same")
        assert new1 is True
        assert new2 is False
        assert job1.job_id == job2.job_id

    @pytest.mark.asyncio
    async def test_priority_ordering(self, queue):
        await queue.submit({}, "req-low", priority="low")
        await queue.submit({}, "req-high", priority="high")
        await queue.submit({}, "req-normal", priority="normal")

        j1 = await queue.get_next()
        j2 = await queue.get_next()
        j3 = await queue.get_next()

        assert j1.client_req_id == "req-high"
        assert j2.client_req_id == "req-normal"
        assert j3.client_req_id == "req-low"

    @pytest.mark.asyncio
    async def test_cancel(self, queue):
        job, _ = await queue.submit({}, "req-1")
        assert queue.cancel(job.job_id) is True
        assert job.state == JobState.CANCELLED

    @pytest.mark.asyncio
    async def test_cancel_nonexistent(self, queue):
        assert queue.cancel("nonexistent") is False

    @pytest.mark.asyncio
    async def test_cancel_already_finished(self, queue):
        job, _ = await queue.submit({}, "req-1")
        job.mark_started()
        job.mark_succeeded({})
        assert queue.cancel(job.job_id) is False

    @pytest.mark.asyncio
    async def test_overflow(self):
        q = JobQueue(max_size=2)
        await q.submit({}, "req-1")
        await q.submit({}, "req-2")
        with pytest.raises(QueueOverflowError):
            await q.submit({}, "req-3")

    @pytest.mark.asyncio
    async def test_get_job(self, queue):
        job, _ = await queue.submit({}, "req-1")
        found = queue.get_job(job.job_id)
        assert found is job
        assert queue.get_job("nonexistent") is None

    @pytest.mark.asyncio
    async def test_get_queued_jobs(self, queue):
        await queue.submit({}, "req-1")
        await queue.submit({}, "req-2")
        queued = queue.get_queued_jobs()
        assert len(queued) == 2
