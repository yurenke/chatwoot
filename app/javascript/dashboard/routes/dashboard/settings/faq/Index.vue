<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

import APIHelper from 'dashboard/helper/APIHelper';
import axios from 'axios';

const API = APIHelper(axios);

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');

const files = ref([]);
const loading = ref(false);

const fileInput = ref(null);

const uploading = ref(false);
const uploadProgress = ref(0);
const uploadFileName = ref('');

const deletingFile = ref(null);
const showDeleteModal = ref(false);

let pollingTimer = null;

const POLLING_INTERVAL =
  window.chatwootConfig?.faqPollingInterval * 1000 || 10000;

/* --------------------------------
   helpers
-------------------------------- */

const formatSize = size => {
  if (!size) return '-';

  const kb = size / 1024;
  if (kb < 1024) return `${kb.toFixed(1)} KB`;

  return `${(kb / 1024).toFixed(1)} MB`;
};

const statusBadge = status => {
  const s = status || 'uploaded';

  if (s === 'indexed') return 'bg-n-emerald-3 text-n-emerald-11';
  if (s === 'indexing') return 'bg-n-blue-3 text-n-blue-11';
  if (s === 'processing') return 'bg-n-amber-3 text-n-amber-11';
  if (s === 'failed') return 'bg-n-ruby-3 text-n-ruby-11';

  return 'bg-n-slate-3 text-n-slate-11';
};

const statusLabel = status => {
  const map = {
    uploaded: 'FAQ.STATUS.UPLOADED',
    processing: 'FAQ.STATUS.PROCESSING',
    indexing: 'FAQ.STATUS.INDEXING',
    indexed: 'FAQ.STATUS.INDEXED',
    failed: 'FAQ.STATUS.FAILED',
  };

  return t(map[status] || 'FAQ.STATUS.UPLOADED');
};

const hasProcessing = computed(() =>
  files.value.some(
    f =>
      !f.status ||
      f.status === 'uploaded' ||
      f.status === 'processing' ||
      f.status === 'indexing'
  )
);

/* --------------------------------
   API
-------------------------------- */

const fetchDocuments = async () => {
  try {
    loading.value = true;

    const res = await API.get(
      `/api/v1/accounts/${accountId.value}/faq_documents`
    );

    const data = res.data;

    if (!Array.isArray(data)) {
      console.error('Unexpected API response', data);
      files.value = [];
      return;
    }

    files.value = data.map(f => ({
      ...f,
      status: f.status || 'uploaded',
    }));

    if (!hasProcessing.value) {
      stopPolling();
    }
  } catch (e) {
    console.error('fetchDocuments failed', e);
  } finally {
    loading.value = false;
  }
};

/* --------------------------------
   upload
-------------------------------- */

const selectFile = () => {
  fileInput.value.click();
};

const upload = async event => {
  const file = event.target.files[0];
  if (!file) return;

  uploadFileName.value = file.name;
  uploading.value = true;
  uploadProgress.value = 0;

  try {
    const res = await API.post(
      `/api/v1/accounts/${accountId.value}/faq_documents/upload_url`,
      {
        filename: file.name,
        content_type: file.type,
      }
    );

    const data = res.data;

    await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.onprogress = e => {
        if (e.lengthComputable) {
          uploadProgress.value = Math.round(
            (e.loaded / e.total) * 100
          );
        }
      };

      xhr.onload = () => resolve();
      xhr.onerror = () => reject();

      xhr.open('PUT', data.url);
      xhr.setRequestHeader('Content-Type', file.type);
      xhr.send(file);
    });

    uploading.value = false;

    await fetchDocuments();

    if (hasProcessing.value) {
      startPolling();
    }

    window.$toast?.success(t('FAQ.UPLOAD_SUCCESS'));
  } catch (e) {
    console.error('Upload failed', e);
    uploading.value = false;
    window.$toast?.error(t('FAQ.UPLOAD_FAILED'));
  }
};

/* --------------------------------
   delete
-------------------------------- */

const confirmDelete = key => {
  deletingFile.value = key;
  showDeleteModal.value = true;
};

const deleteFile = async () => {
  try {
    const key = deletingFile.value;

    await API.delete(
      `/api/v1/accounts/${accountId.value}/faq_documents`,
      {
        data: { key }
      }
    );

    window.$toast?.success(t('FAQ.DELETE_SUCCESS'));

    await fetchDocuments();
  } catch (e) {
    console.error('Delete failed', e);
    window.$toast?.error(t('FAQ.DELETE_FAILED'));
  } finally {
    showDeleteModal.value = false;
    deletingFile.value = null;
  }
};

/* --------------------------------
   polling
-------------------------------- */

const startPolling = () => {
  if (pollingTimer) return;

  pollingTimer = setInterval(fetchDocuments, POLLING_INTERVAL);
};

const stopPolling = () => {
  if (pollingTimer) {
    clearInterval(pollingTimer);
    pollingTimer = null;
  }
};

/* --------------------------------
   lifecycle
-------------------------------- */

onMounted(async () => {
  await fetchDocuments();

  if (hasProcessing.value) {
    startPolling();
  }
});

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="$t('FAQ.LOADING')"
    :no-records-found="!files.length"
    :no-records-message="$t('FAQ.EMPTY')"
  >
    <!-- HEADER -->
    <template #header>
      <BaseSettingsHeader
        :title="$t('FAQ.TITLE')"
        feature-name="faq"
      >
        <template v-if="files.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('FAQ.DOCUMENT_COUNT', { count: files.length }) }}
          </span>
        </template>

        <template #actions>
          <Button
            :label="$t('FAQ.UPLOAD_BUTTON')"
            icon="i-lucide-upload"
            size="sm"
            @click="selectFile"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <!-- BODY -->
    <template #body>
      <div class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="file in files"
          :key="file.key"
          class="flex justify-between items-center py-4"
        >
          <div class="flex items-start gap-3">
            <div class="text-n-slate-10 mt-1">
              <i class="i-lucide-file-text text-lg" />
            </div>

            <div class="flex flex-col gap-1">
              <span class="text-heading-3 text-n-slate-12">
                {{ file.filename }}
              </span>

              <div class="flex items-center gap-2 text-body-main text-n-slate-11">
                <span>{{ formatSize(file.size) }}</span>

                <div class="w-px h-3 bg-n-strong rounded-lg" />

                <span>
                  {{ new Date(file.created_at).toLocaleString() }}
                </span>

                <div class="w-px h-3 bg-n-strong rounded-lg" />

                <span
                  class="flex items-center gap-1 px-2 py-0.5 rounded text-xs"
                  :class="statusBadge(file.status)"
                >
                  <i
                    v-if="file.status === 'uploaded'"
                    class="i-lucide-upload text-xs"
                  />

                  <i
                    v-if="file.status === 'processing' || file.status === 'indexing'"
                    class="i-lucide-loader animate-spin text-xs"
                  />

                  <i
                    v-if="file.status === 'indexed'"
                    class="i-lucide-check text-xs"
                  />

                  <i
                    v-if="file.status === 'failed'"
                    class="i-lucide-alert-circle text-xs"
                  />

                  {{ statusLabel(file.status) }}
                </span>
              </div>
            </div>
          </div>

          <!-- DELETE -->
          <div
            class="cursor-pointer text-n-ruby-9 hover:text-n-ruby-11"
            @click="confirmDelete(file.key)"
          >
            <i class="i-lucide-trash-2" />
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>

  <!-- hidden file input -->
  <input
    ref="fileInput"
    type="file"
    class="hidden"
    @change="upload"
  />

  <!-- UPLOAD MODAL -->
  <div
    v-if="uploading"
    class="fixed inset-0 flex items-center justify-center bg-n-alpha-3 backdrop-blur z-50"
  >
    <div
      class="bg-n-alpha-3 backdrop-blur outline outline-1 outline-n-container rounded-lg p-6 w-[360px] shadow-lg text-center"
    >
      <div class="text-lg font-semibold mb-3">
        {{ t('FAQ.UPLOAD_MODAL_TITLE') }}
      </div>

      <div class="text-sm text-n-slate-10 mb-4">
        {{ uploadFileName }}
      </div>

      <div class="w-full bg-n-slate-3 rounded h-2 mb-2 overflow-hidden">
        <div
          class="bg-n-brand h-2 rounded transition-all duration-300 ease-out"
          :style="{ width: uploadProgress + '%' }"
        />
      </div>

      <div class="text-sm text-n-slate-11">
        {{ uploadProgress }}%
      </div>
    </div>
  </div>

  <!-- DELETE MODAL -->
  <div
    v-if="showDeleteModal"
    class="fixed inset-0 flex items-center justify-center bg-n-alpha-3 backdrop-blur z-50"
  >
    <div
      class="bg-n-alpha-3 backdrop-blur outline outline-1 outline-n-container rounded-lg p-6 w-[360px] shadow-lg text-center"
    >
      <div class="text-lg font-semibold mb-4">
        {{ t('FAQ.DELETE_CONFIRM_TITLE') }}
      </div>

      <div class="text-sm text-n-slate-10 mb-6">
        {{ t('FAQ.DELETE_CONFIRM_TEXT') }}
      </div>

      <div class="flex justify-center gap-4">
        <Button
          :label="t('FAQ.CANCEL')"
          size="sm"
          @click="showDeleteModal = false"
        />

        <Button
          :label="t('FAQ.CONFIRM')"
          size="sm"
          slate
          class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
          @click="deleteFile"
        />
      </div>
    </div>
  </div>
</template>