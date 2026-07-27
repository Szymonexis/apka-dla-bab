import { Ionicons } from '@expo/vector-icons';
import DateTimePicker from '@react-native-community/datetimepicker';
import React, { useState } from 'react';
import {
  FlatList,
  Modal,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  type TextInputProps,
} from 'react-native';

import { colors, radius } from '../lib/theme';
import { dateStr, parseLocalDate, prettyDate } from '../lib/util';

export function Input({ label, style, ...props }: TextInputProps & { label?: string }) {
  return (
    <View style={styles.fieldWrap}>
      {label ? <Text style={styles.label}>{label}</Text> : null}
      <TextInput
        placeholderTextColor={colors.muted}
        {...props}
        style={[styles.input, props.multiline ? styles.multiline : null, style]}
      />
    </View>
  );
}

export function PrimaryButton({
  title,
  onPress,
  disabled,
}: {
  title: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <TouchableOpacity
      style={[styles.primaryBtn, disabled ? { opacity: 0.5 } : null]}
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.8}
    >
      <Text style={styles.primaryBtnText}>{title}</Text>
    </TouchableOpacity>
  );
}

export function OutlineButton({
  title,
  onPress,
  danger,
  style,
}: {
  title: string;
  onPress: () => void;
  danger?: boolean;
  style?: object;
}) {
  return (
    <TouchableOpacity
      style={[styles.outlineBtn, danger ? { borderColor: colors.error } : null, style]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <Text style={{ color: danger ? colors.error : colors.primary, fontWeight: '600' }}>{title}</Text>
    </TouchableOpacity>
  );
}

/** Pole-przycisk otwierające coś (picker, kalendarz). */
export function FieldButton({
  label,
  value,
  placeholder,
  onPress,
  onClear,
  disabled,
}: {
  label?: string;
  value: string | null;
  placeholder?: string;
  onPress: () => void;
  onClear?: () => void;
  disabled?: boolean;
}) {
  return (
    <View style={styles.fieldWrap}>
      {label ? <Text style={styles.label}>{label}</Text> : null}
      <TouchableOpacity
        style={[styles.input, styles.fieldButton, disabled ? { opacity: 0.5 } : null]}
        onPress={onPress}
        disabled={disabled}
        activeOpacity={0.7}
      >
        <Text style={{ color: value ? colors.text : colors.muted, flex: 1 }}>
          {value ?? placeholder ?? 'Wybierz...'}
        </Text>
        {onClear && value ? (
          <TouchableOpacity onPress={onClear} hitSlop={8}>
            <Ionicons name="close" size={18} color={colors.muted} />
          </TouchableOpacity>
        ) : (
          <Ionicons name="chevron-down" size={18} color={colors.muted} />
        )}
      </TouchableOpacity>
    </View>
  );
}

export interface PickerOption {
  value: string;
  label: string;
}

/** Prosty picker: pole + modal z listą opcji. */
export function PickerField({
  label,
  value,
  options,
  onChange,
  disabled,
}: {
  label?: string;
  value: string;
  options: PickerOption[];
  onChange: (value: string) => void;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const current = options.find((o) => o.value === value);
  return (
    <>
      <FieldButton
        label={label}
        value={current?.label ?? null}
        onPress={() => setOpen(true)}
        disabled={disabled}
      />
      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <TouchableOpacity style={styles.modalBackdrop} activeOpacity={1} onPress={() => setOpen(false)}>
          <View style={styles.modalSheet}>
            <FlatList
              data={options}
              keyExtractor={(o) => o.value}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.option}
                  onPress={() => {
                    setOpen(false);
                    onChange(item.value);
                  }}
                >
                  <Text style={{ color: colors.text, flex: 1 }}>{item.label}</Text>
                  {item.value === value ? (
                    <Ionicons name="checkmark" size={18} color={colors.primary} />
                  ) : null}
                </TouchableOpacity>
              )}
            />
          </View>
        </TouchableOpacity>
      </Modal>
    </>
  );
}

/** Data 'YYYY-MM-DD' (albo null = brak terminu, gdy allowClear). */
export function DateField({
  label,
  value,
  onChange,
  allowClear,
  placeholder,
}: {
  label?: string;
  value: string | null;
  onChange: (value: string | null) => void;
  allowClear?: boolean;
  placeholder?: string;
}) {
  const [show, setShow] = useState(false);
  return (
    <>
      <FieldButton
        label={label}
        value={value ? prettyDate(value) : null}
        placeholder={placeholder ?? 'Wybierz datę'}
        onPress={() => setShow(true)}
        onClear={allowClear ? () => onChange(null) : undefined}
      />
      {show ? (
        <DateTimePicker
          value={value ? parseLocalDate(value) : new Date()}
          mode="date"
          onChange={(event, selected) => {
            setShow(false);
            if (event.type !== 'dismissed' && selected) onChange(dateStr(selected));
          }}
        />
      ) : null}
    </>
  );
}

/** Godzina {hour, minute}. */
export function TimeField({
  label,
  value,
  onChange,
}: {
  label?: string;
  value: { hour: number; minute: number };
  onChange: (value: { hour: number; minute: number }) => void;
}) {
  const [show, setShow] = useState(false);
  const asDate = new Date();
  asDate.setHours(value.hour, value.minute, 0, 0);
  const pad = (n: number) => n.toString().padStart(2, '0');
  return (
    <>
      <FieldButton
        label={label}
        value={`${pad(value.hour)}:${pad(value.minute)}`}
        onPress={() => setShow(true)}
      />
      {show ? (
        <DateTimePicker
          value={asDate}
          mode="time"
          is24Hour
          onChange={(event, selected) => {
            setShow(false);
            if (event.type !== 'dismissed' && selected) {
              onChange({ hour: selected.getHours(), minute: selected.getMinutes() });
            }
          }}
        />
      ) : null}
    </>
  );
}

export function Segmented({
  options,
  value,
  onChange,
}: {
  options: PickerOption[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <View style={styles.segmented}>
      {options.map((o) => {
        const active = o.value === value;
        return (
          <TouchableOpacity
            key={o.value}
            style={[styles.segment, active ? styles.segmentActive : null]}
            onPress={() => onChange(o.value)}
          >
            <Text style={{ color: active ? '#fff' : colors.text, fontWeight: '600', fontSize: 13 }}>
              {o.label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

export interface SheetAction {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  onPress: () => void;
}

/** Dolny arkusz z akcjami (odpowiednik showModalBottomSheet z Fluttera). */
export function ActionSheet({
  visible,
  onClose,
  actions,
}: {
  visible: boolean;
  onClose: () => void;
  actions: SheetAction[];
}) {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity style={styles.sheetBackdrop} activeOpacity={1} onPress={onClose}>
        <View style={styles.sheet}>
          {actions.map((a) => (
            <TouchableOpacity
              key={a.label}
              style={styles.sheetItem}
              onPress={() => {
                onClose();
                a.onPress();
              }}
            >
              <Ionicons name={a.icon} size={22} color={colors.primary} style={{ marginRight: 14 }} />
              <Text style={{ color: colors.text, fontSize: 16 }}>{a.label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

const styles = StyleSheet.create({
  fieldWrap: { marginBottom: 12 },
  label: { fontSize: 12, color: colors.muted, marginBottom: 4, marginLeft: 2 },
  input: {
    borderWidth: 1,
    borderColor: colors.outline,
    borderRadius: radius.field,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    color: colors.text,
    backgroundColor: colors.surface,
  },
  multiline: { minHeight: 110, textAlignVertical: 'top' },
  fieldButton: { flexDirection: 'row', alignItems: 'center' },
  primaryBtn: {
    backgroundColor: colors.primary,
    borderRadius: radius.field,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 8,
  },
  primaryBtnText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  outlineBtn: {
    borderWidth: 1,
    borderColor: colors.primary,
    borderRadius: radius.field,
    paddingVertical: 11,
    alignItems: 'center',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    padding: 32,
  },
  modalSheet: {
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    maxHeight: 420,
    paddingVertical: 6,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 18,
    paddingVertical: 13,
  },
  segmented: {
    flexDirection: 'row',
    borderWidth: 1,
    borderColor: colors.primary,
    borderRadius: radius.field,
    overflow: 'hidden',
    marginBottom: 12,
  },
  segment: { flex: 1, paddingVertical: 10, alignItems: 'center' },
  segmentActive: { backgroundColor: colors.primary },
  sheetBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingVertical: 10,
    paddingBottom: 28,
  },
  sheetItem: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 22, paddingVertical: 14 },
});
